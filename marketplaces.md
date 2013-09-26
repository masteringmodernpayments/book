[marketplaces-stripe-connect]: https://stripe.com/connect
[marketplaces-stripe-payouts]: https://stripe.com/blog/send-payouts-with-stripe
[marketplaces-OmniAuth]: https://github.com/intridea/omniauth
[marketplaces-OmniAuth::StripeConnect]: https://github.com/isaacsanders/omniauth-stripe-connect
[marketplaces-stripe-connect-register]: https://stripe.com/docs/connect/getting-started#register-application

# Marketplaces

Marketplaces let multiple people sell goods and services on the same site at the same time. Stripe lets your SaaS app implement a marketplace in two different ways. With [Stripe Connect][marketplaces-stripe-connect] your users connect their Stripe account with yours, allowing you to make charges with their Stripe account securely and passing fees through directly. This is great for a technical audience or for a marketplace who's participants want to be able to manage their own Stripe account.

Stripe recently added the ability to send transfers to any authorized US checking account via ACH transfers using a feature called [Payouts][marketplaces-stripe-payouts]. This enables for more nuanced interactions with your marketplace participants. For example, you could send their collected payments to them once a month, or only if they've passed a certain threshold. Payouts also allows non-technical people to easily participate in your marketplace since they don't have to leave your site to create a Stripe account via Stripe's OAuth flow.

Both Connect and Payouts are easily integrated into a Rails application with a few minor changes. In fact, depending on your use case you may want to hook up both and let market participants decide which is best for them.

## Connect

Connect is Stripe's OAuth2-based way for your application to create transactions, customers, subscription plans, and everything else Stripe has to offer on behalf of another user. Hooking it up to your Rails application is easy because someone else has done all of the hard work for you in a gem named [OmniAuth::StripeConnect][marketplaces-OmniAuth::StripeConnect]. This gem uses the [OmniAuth][marketplaces-OmniAuth] OAuth abstraction library to allow you to connect to your users' Stripe accounts by simply sending them to `/auth/stripe_connect`, which will direct them through the OAuth2 dance and bring them back to your site.

To start hooking this up, simply add the gems to your `Gemfile`:

```ruby
gem 'omniauth'
gem 'omniauth-stripe-connect'
```

Then, add the middleware in an initializer `config/initializers/omniauth.rb`:

```ruby
Rails.application.config.middleware.use OmniAuth::Builder do
  provider :stripe_connect, ENV['STRIPE_CONNECT_CLIENT_ID'], ENV['STRIPE_SECRET_KEY']
end
```

`STRIPE_SECRET_KEY` is the same key we set up in `config/initializers/stripe.rb` way back in the beginning. To get the value for `STRIPE_CONNECT_CLIENT_ID` you need to [register an application][stripe-connect-register]. This should be a simple process but I've had trouble with it before. Feel free to contact Stripe's very helpful support if you hit any snags.

When you send the user through `/auth/stripe_connect`, after registering them or logging them in Stripe will send them back to `/auth/stripe_connect/callback` (via OmniAuth). Add a route to handle this:

```ruby
get '/auth/stripe_connect/callback', to: 'stripe_connect#create'
```

Let's set up that controller in `app/controllers/stripe_connect.rb`:

```ruby
class StripeConnectController < ApplicationController

  def create
    auth_hash = params[:auth_hash]
    current_user.stripe_id = auth_hash['uid']
    current_user.stripe_access_key = auth_hash['credentials']['token']
    current_user.stripe_publishable_key = auth_hash['info']['stripe_publishable_key']
    current_user.save!
    flash[:notice] = "Stripe info saved"
    redirect_to '/'
  end

end
```

OmniAuth populates a param named `auth_hash` containing all of the OAuth information that Stripe returned. The salient bits are the user's `uid`, their `stripe_access_key`, and `stripe_publishable_key`.

### Make Charges with a User's Credentials

To actually charge cards with an authenticated user's credentials all you have to do is pass the user's access key to the create call:

```ruby
charge = Stripe::Charge.create(
  {
    amount:          1000,
    application_fee: 100,
    currency:        'usd',
    card:            params[:stripeToken],
    description:     'customer@example.com',
  },
  user.stripe_access_key
)
```

Note also in this example that we're passing the `application_fee` option. This subtracts that amount from the total `amount` after Stripe subtracts it's fee. So, in this example the user would get $8.41 deposited in their account seven days later:

```text
Amount             1000
Stripe Fee:          59 (1000 * 0.029) + 30
Application Fee     100
-----------------------
Total Paid to User  841
```

Other than the optional application fee and passing the user's access key to `Stripe::Charge#create` there's nothing else you have to do for Connect.

## Payouts

Stripe Payouts are another, more flexible way to implement marketplaces with Stripe. Instead of connecting to a user's Stripe account and making charges through it, you get authorization to make deposits directly into their checking account. Charges run through your Stripe account and you decide when to pay out to the user. This is useful if your marketplace particpants don't care that you're using Stripe, or if signing them up for an account is more burdensome than you want to deal with. For example, one of the initial customers for Stripe Payouts was Lyft, a do-it-yourself taxi service. Drivers give Lyft their checking account info who then create `Stripe::Recipient`s. Passengers pay with their credit cards through Lyft's mobile app, which uses Stripe behind the scenes to actually run payments. Drivers never have to deal with Stripe directly, instead Lyft just pays out to their accounts periodically.

One thing to keep in mind is that once you create a `Stripe::Recipient` and turn on production transfers in Stripe's management interface *your account will no longer receive automatic payouts*. Instead, Stripe will hold funds in your account until you tell them where to send them.

### Collect Account Info

Theoretically you could collect marketplace participants' checking account information via a normal Rails action because PCI-DSS does not consider them sensitive information. However, `stripe.js` provides the capability to tokenize the numbers the same way it tokenizes credit card numbers and you really should take advantage of it. That way sensitive information never touches your server:

```rhtml
<%= form_tag update_checking_account_path(id: @user.id), :class => 'form-horizontal', :id => 'account-form' do %>
  <div class="control-group">
    <label class="control-label" for="fullName">Full Name</label>
    <div class="controls">
      <input type="text" name="fullName" id="fullName" />
    </div>
  </div>

  <div class="control-group">
    <label class="control-label" for="number">Routing Number</label>
    <div class="controls">
      <input type="text" size="9" class="routingNumber" id="number" placeholder="*********"/>
    </div>
  </div>

  <div class="control-group">
    <label class="control-label">Account Number</label>
    <div class="controls">
      <input type="text" class="accountNumber" />
    </div>
  </div>

  <div class="form-row">
    <div class="controls">
      <button type="submit" class="btn btn-primary">Pay</button>
    </div>
  </div>
<% end %>
```

```javascript
$('#account-form').submit(function() {
  Stripe.bankAccount.createToken({
    country: 'US',
    routingNumber: $('.routingNumber').val(),
    accountNumber: $('.accountNumber').val(),
  }, stripeResponseHandler);
  return false;
});

function stripeResponseHandler(response) {
  var form = $('#account-form');
  form.append("<input type='hidden' name='stripeToken' value='" + response.id + "'/>"
  form.get(0).submit();
}
```

This is a simplified form of the normal Stripe card tokenizing form and works basically the same way. You call `Stripe.bankAccount.createToken` with the routing number, account number, and country of the account which we're hard coding to 'US'. `createToken` takes a callback which then appends a hidden input to the form and submits it using the DOM method instead of the jQuery method so we avoid creating loops.

On the server side, just create a `Stripe::Recipient` and save the ID to the user's record:

```ruby
recipient = Stripe::Recipient.create(
  name: params[:fullName],
  type: 'individual',
  bank_account: params[:stripeToken]
)

current_user.update_attributes(:stripe_recipient_id => recipient.id)
```

Now, just create charges as normal while keeping track of which recipient the charges are intended for. The easiest way to do this is to attach the `recipient_id` or `user_id` to a `Sale` record.

### Create Transfers

When you're ready to pay out to a recipient, either on a schedule or when the user requests it, all you have to do is create a `Stripe::Transfer`:

```ruby
transfer = Stripe::Transfer.create(
  amount:      10000,
  currency:    'usd',
  recipient:   user.stripe_recipient_id,
  description: 'Transfer'
)
```

This will initiate a transfer of $100 into the user's registered account. If you instead use `self` for the `recipient` option it will transfer the requested amount into the account you've attached to the Stripe account. If you've configured a callback URL Stripe will send you an event when the transfer completes named `transfer.paid`. You can use this event to send the user a receipt or a notification. You'll also get an event `transfer.failed` if there was an error anywhere along the line.

Each transfer costs a fixed $0.25 which is removed from your Stripe account at the time you create the transfer. If the transfer fails Stripe charges you $1, which will again be removed from your account.
