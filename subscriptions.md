---
discussion_issue: 9
---

# Subscriptions

* Learn how to set up basic subscriptions
* Create composable service objects
* Advanced subscriptions techniques

---

So far in this book we've talked about how to sell products once. A customer selects a product, puts their information in, and hits the "buy now" button, and that's end of our interaction with them.

The majority of SaaS businesses don't operate that way. Most of them will want their customers to pay on a regular schedule. Stripe has built-in support for these kinds of subscription payments that is easy to work with and convenient to set up. In this chapter, we're going to go through a basic integration, following the same priciples that we've laid out for the one-time product sales. Then, we'll explore some more advanced topics, including how to effectively use the subscription webhook events, in-depth coverage of Stripe's plans, and options for reporting.

## Basic Integration

For this example, we're going to add a simple subscription system where people can sign up to receive periodic download links, like magazine articles.

Let's start by making a few models. We'll need models to keep track of our pricing plans and each user's subscriptions, since they may sign up for one or more magazine.


```bash
$ rails g model plan \
    stripe_id:string \
    name:string \
    description:text \
    amount:integer \
    interval:string \
    published:boolean
```

```bash
$ rails g model subscription \
    user:references \
    plan:references \
    stripe_id:string
```

```bash
$ rails g migration AddStripeCustomerIdToUser \
    stripe_customer_id:string
```

Open up the models and add audit trails:

```ruby
class Plan < ActiveRecord::Base
  has_paper_trail
  validates :stripe_id, uniqueness: true
end
```

```ruby
class Subscription < ActiveRecord::Base
  belongs_to :user
  belongs_to :plan

  has_paper_trail
end
```

Notice we also added a uniqueness constraint to `Plan`. Re-using Stripe plan IDs is technically allowed but it's not a very good idea.

### Service Objects

In this integration we're going to be using service objects to encapsulate the business logic of creating users and subscriptions. In our usage, a service object lives in `/app/services` and contains one main class method named `call` which receives all of the dependencies that the object needs to do it's job.

Here's our `CreateUser` service, in `/app/services/create_user.rb`:

```ruby
class CreateUser
  def self.call(email_address)

    user = User.find_by(email: email_address)

    return user if user.present?

    raw_token, enc_token = Devise.token_generator.generate(
      User, :reset_password_token)
    password = SecureRandom.hex(32)

    user = User.create!(
      email: email_address,
      password: password,
      password_confirmation: password,
      reset_password_token: enc_token,
      reset_password_sent_at: Time.now
    )

    return user, raw_token
  end
end
```

In our signup flow, we are going to have the user provide their email address at the same time they give us their credit card. Internally, Devise will set up a password reset token for us if we ask, but there's no way to get out the raw token so we can send it to the user so we have to do it ourselves. `NOTE <-- wtf`

`CreateUser.call` takes an email address and first attempts to look up the user with that email address. If there isn't one, it proceeds to generate the Devise password reset token, create the user, and then return both the user and the token.

Now that we can create a user, let's create a subscription:

```ruby
class CreateSubscription
  def self.call(plan, email_address, token)
    user, raw_token = CreateUser.call(email_address)

    subscription = Subscription.new(
      plan: plan,
      user: user
    )

    begin
      stripe_sub = nil
      if user.stripe_customer_id.blank?
        customer = Stripe::Customer.create(
          card: token,
          email: user.email,
          plan: plan.stripe_id,
        )
        user.stripe_customer_id = customer.id
        user.save!
        stripe_sub = customer.subscriptions.first
      else
        customer = Stripe::Customer.retrieve(user.stripe_customer_id)
        stripe_sub = customer.subscriptions.create(
          plan: plan.stripe_id
        )
      end

      subscription.stripe_id = stripe_sub.id

      subscription.save!


      UserMailer.send_receipt(user.id, plan.id, raw_token)
          if subscription.errors.empty?

    rescue Stripe::StripeError => e
      subscription.errors[:base] << e.message
    end

    subscription
  end 
end
```

One of the best things about service objects is how easy it is to compose them. We can just use the `CreateUser` service we set up to create a user wherever we want, including in other service objects.

First we create the user and then a `Subscription` object. Next, we actually talk to Stripe. All we have to do is create a `Stripe::Customer` object with the plan, token, and email address of the user. We store the customer ID onto our `Subscription` object for later reference then send a receipt email which will contain a link for the user to set up their password.

How do we get those plans, though? Let's create one more service object for creating new plans in our database and propagating them to Stripe:

```ruby
class CreatePlan
  def self.call(options={})
    plan = Plan.new(options)

    if !plan.valid?
      return plan
    end

    begin
      Stripe::Plan.create(
        id: options[:stripe_id],
        amount: options[:amount],
        currency: 'usd',
        interval: options[:interval],
        name: options[:name],
      )
    rescue Stripe::StripeError => e
      subscription.errors[:base] << e.message
    end

    plan.save!

    return plan
  end
end
```

All this does is pass the options hash through to `Plan#new` and then attempts to create a Stripe-level plan with those same options. If everything goes well, it then saves our new plan and returns it. It's very easy to use this service object in the console so we're not going to build out a controller here. Here's an example of creating a plan from the console:

```bash
irb(main):001:0> CreatePlan.call(stripe_id: 'test_plan', name: 'Test Plan', amount: 500, interval: 'month', description: 'Test Plan', published: false)
```

### Controller

The next thing we have to do is actually use the service objects. Thankfully, that's pretty simple:

```ruby
class SubscriptionsController < ApplicationController
  skip_before_filter :authenticate_user!

  before_filter :load_plans

  def index
  end

  def new
    @subscription = Subscription.new
    @plan = Plan.find(params[:plan_id])
  end

  def create
    @subscription = CreateSubscription.call(
      params[:email_address],
      Plan.find(params[:plan_id]),
      params[:stripeToken]
    )
    if @subscription.errors.blank?
      flash[:notice] = 'Thank you for your purchase!' +
        'Please click the link in the email we just sent ' +
        'you to get started.'
      redirect_to :root
    else
      render :new
    end
  end

protected

  def load_plans
    @plans = Plan.where(published: true).order('price')
  end

end
```

Before we do anything else, we have to load the published plans so they're available for the actions. Other than that, this is a normal, ordinary, every day Rails controller. We use the service object we created previously to actually create the subscription, and we check that it made it all the way through the process without any errors. Let's fill out the views:

`/app/views/subscriptions/index.html.erb`:

```rhtml
<% @plans.each do |plan| %>
  <%= link_to "#{plan.name} (#{plan.price})",
        new_subscription_path(@plan) %>
<% end %>
```

`/app/views/subscriptions/new.html.erb`:

```rhtml
<% unless @subscription.errors.blank? %>
  <%= @subscription.errors.full_messages.to_sentence %>
<% end %>

<h2>Subscribing to <%= @plan.name %></h2>

<%= form_for @subscription do |f| %>
  <span class="payment-errors"></span>

  <div class="form-row">
    <label>
      <span>Email Address</span>
      <input type="email" size="20" name="email_address"/>
    </label>
  </div>

  <div class="form-row">
    <label>
      <span>Card Number</span>
      <input type="text" size="20" data-stripe="number"/>
    </label>
  </div>

  <div class="form-row">
    <label>
      <span>CVC</span>
      <input type="text" size="4" data-stripe="cvc"/>
    </label>
  </div>

  <div class="form-row">
    <label>
      <span>Expiration (MM/YYYY)</span>
      <input type="text" size="2" data-stripe="exp-month"/>
    </label>
    <span> / </span>
    <input type="text" size="4" data-stripe="exp-year"/>
  </div>

  <button type="submit">Pay Now</button>
<% end %>

<%= javascript_tag do %>
  Stripe.setPublishableKey('<%= Rails.configuration.stripe['publishable_key'] %>');
<% end %>
```

`/app/assets/javascripts/subscriptions.js`:

```javascript
jQuery(function($) {
  $('#payment-form').submit(function(event) {
    var $form = $(this);

    $form.find('button').prop('disabled', true);

    Stripe.card.createToken($form, stripeResponseHandler);

    return false;
  });
});

function stripeResponseHandler(status, response) {
  var $form = $('#payment-form');

  if (response.error) {
    // Show the errors on the form
    $form.find('.payment-errors').text(response.error.message);
    $form.find('button').prop('disabled', false);
  } else {
    // response contains id and card, which contains additional card details
    var token = response.id;
    // Insert the token into the form so it gets submitted to the server
    $form.append($('<input type="hidden" name="stripeToken" />').val(token));
    // and submit
    $form.get(0).submit();
  }
};
```

With those in place, you should be able to click through and create paying users.

### Multiple Subscriptions

Stripe allows a customer to have multiple subscriptions. Because of the way we've set up our `Subscription` class, this is trivial to accomplish in our application. Basically, all you have to do is call `CreateSubscription.call()`, passing in the user's email address, the plan, and a blank token, like this:

```ruby
CreateSubscription.call(
  current_user.email_address,
  some_plan,
  ''
)
```

### TODO Upgrading and Downgrading Subscriptions

What about when a user wants to change their plan? For example, a user wants to go from the 10 frobs a month plan to one with 1000. Or maybe go the other way?

Let's wrap that up in another service object:

```ruby
class ChangePlan
  def self.call(subscription, to_plan)
    from_plan = subscription.plan
    begin
      user = subscription.user
      customer = Stripe::Customer.retrieve(user.stripe_customer_id)
      stripe_sub = customer.subscriptions.retrieve(subscription.stripe_id)

      stripe_sub.plan = to_plan.stripe_id
      stripe_sub.save!
      subscription.plan = to_plan
      subscription.save!
    rescue Stripe::StripeError => e
      subscription.errors[:base] << e.message
    end

    subscription
  end
end
```

What if the user wants to change or update their card? Again, pretty simple. Just set up a form like above but just with the card attributes, then create another service object to handle the action:

```ruby
class ChangeSubscriptionCard
  def self.call(subscription, token)
    begin
      user = subscription.user
      customer = Stripe::Customer.retrieve(user.stripe_customer_id)
      stripe_sub = customer.subscriptions.retrieve(subscription.stripe_id)

      stripe_sub.card = token
      stripe_sub.save!
    rescue Stripe::StripeError => e
      subscription.errors[:base] << e.message
    end

    subscription
  end
end
```

The controller actions for both of these are self-explanatory. Just grab the subscription in question and the plan or token and pass them to the appropriate service object's `call` method.

## Dunning

Sometimes customers don't pay their bill, often through no fault of their own. The process of communicating with your customers to get them to pay is called "dunning" and it's vital for any type of business. For a subscription SaaS using Stripe where the customer's card is billed automatically every period the dunning process kicks in when a charge fails for some reason and we send them an email. The next month we send them another, more strongly worded email, eventually leading to cancelling their account.

Really, though, you don't want to let the process even get started. The number one reason why subscription charges start getting declined is that the customer's card expires. Since you're saving the customer's card expiration in your database (if you're not, you should start), it's a trivial matter to find all of the customers that have an expiration coming up and send them a short reminder email:

```ruby
expiring_customers = Customer.where(
  'date_reminded is null and expiration_date <= ?',
  Date.today() + 30.days
)

expiring_customers.each do |customer|
  StripeMailer.card_expiring(customer).deliver
  customer.update_attributes(date_reminded: Date.today)
end
```

Andrew Culver is the author of [Koudoku][subscriptions-koudoku] and currently is developing a product to automate this process. He has had phenomenal success reducing churn using this method:

> In one product where this approach has been taken, the campaign stops 50% of expiring credit card accounts from having a failed payment. For the remaining 50% we have another campaign that kicks in once the payment fails. Then after a couple days an email is sent to the sales team. Before we automated this process it was a major source of pain for us to manage these accounts going delinquent. It's still a source of work for our sales team and a source of customer churn for us, but it's much smaller and more manageable overall.

Andrew's campaign sends emails at 30, 15, and three days before card expiration, as well as the day of. Make sure to describe what's going on and give them an easy way to login to your app and update their card. If the payment does eventually fail, make sure to contact them again. According to [Patrick McKenzie][subscriptions-patio11-rainy-day] you should also include a P.S. to the effect that you're a small business, not a bank, and that they're not in trouble or anything. You're sure it's a mistake so you won't be cutting them off for a few days.

Speaking of cutting them off, you really shouldn't automatically cancel anyone's account without a manual review process. Charges fail sometimes and it's nobody's fault, which is why Stripe automatically retries for you for a configurable number of days. After that's up and the charge finally fails, send yourself an email and follow up with the customer, either by email or over the phone.

There's one more aspect to dunning: following up on cancelled accounts. If a high value customer decides to cancel, give them a call and ask if there's anything you can do to change their mind. It's worth a shot, and most of the time you can work something out.

## Utility-style Usage Billing

Handling a basic subscription is straight forward and well covered in the example apps. Let's say, however, you're building an app where you want metered billing like a phone bill. You'd have a basic subscription for access and then monthly invoicing for anything else. Stripe has a feature they call [Invoices][subscriptions-stripe-invoices] that makes this easy. For example, you want to allow customers to send email to a list and base the charge it on how many emails get sent. You could do something like this:

```ruby
class EmailSend < ActiveRecord::Base
  # ...

  belongs_to :user
  after_create :add_invoice_item

  def add_invoice_item
    Stripe::InvoiceItem.create(
      customer: user.stripe_customer_id,
      amount: 1,
      currency: "usd",
      description: "email to #{address}"
    )
  end
end
```

At the end of the customer's billing cycle Stripe will tally up all of the `InvoiceItems` that you've added to the customer's bill and charge them the total plus their subscription plan's amount.

Stripe will also send you a webook detailing the customer's entire invoice right before they initiate the charge. Instead of creating an invoice item for every single email as it gets sent, you could just create one invoice item for the number of emails sent in the billing period:

```ruby
StripeEvent.configure do |events|
  events.subscribe 'invoice.created' do |event|
    invoice = event.data.object
  
    num_emails = EmailSend.where(
      'created_at between ? and ?',
      [Time.at(invoice.period_start), Time.at(invoice.period_end)]
    ).count
    Stripe::InvoiceItem.create(
      invoice: invoice.id,
      amount: num_emails,
      currency: 'usd',
      description: "#{num_emails} emails sent @ $0.01"
    )
  end
end
```

Note that this can get kind of complicated if invoice items can be charged at different rates. You can either add one `InvoiceItem` per indivicual charge, or you can add one `InvoiceItem` per item type with the amount set to `num_items * item amount`. 

## Free Trials

Stripe supports adding free trials to your subscription plans. You can either set `trial_period_days` on the plan itself, or you can set `trial_ends` to a timestamp on the customer's subscription when you create it. `trial_ends` overrides `trial_days`, which means it's trivial to give a particular customer an extra long or extra short trial.

While a free trial is ongoing, you can manipulate the `trial_ends` attribute on a subscription. You can set it to a future time to extend the trial, or you can set it to the special value "now" to force it to end immediately.

If you want to prevent users from getting muliple trials, you'll need to do the deduplication for yourself. Stripe doesn't handle it. The good news is, Devise won't let multiple accounts share an email address, so we're good to go.

## Reporting

Accepting payments with Stripe is only half of the battle. The other half is making sure you know if you're getting paid properly. I advise a "trust but verify" posture. Of course Stripe is going to be better at actually triggering payments, but we should record them as they happen so we know if Stripe or our bank messes up somehow.

The easiest way to do that is to record transactions as they happen by catching Stripe's webhooks. Let's add an `InvoicePayment` model:

```bash
$ rails g model InvoicePayment \
    stripe_id:string,
    amount:string,
    fee_amount:string,
    user:references,
    subscription:references
```

We can populate these by adding another StripeEvent subscription:

```ruby
StripeEvent.configure do |events|
  events.subscribe('invoice.payment_succeeded') do |event|
    invoice = event.data.object
    user = User.find_by(stripe_id: invoice.customer)
    invoice_sub = invoice.items.select { |i| i.type == 'subscription' }.first.id
    subscription = Subscription.find_by(stripe_id: invoice_sub)

    charge = invoice.charge

    balance_txn = Stripe::BalanceTransaction.retrieve(charge.balance_transaction)

    InvoicePayment.create(
      stripe_id: invoice.id,
      amount: invoice.amount,
      fee_amount: balance_txn.fee,
      user_id: user.id,
      subscription_id: subscription.id
    )
  end
end
```

And now we can run queries against the `invoice_payments` table to see, for example, how much a given user has paid in the last year, or how much revenue a particular subscription plan has generated. There are a few tools that make this easier to work with:

* [Groupdate](https://github.com/ankane/groupdate) makes it trivial to group by various date dimensions
* [Chartkick](http://chartkick.com) generates wonderful charts from the data generated by Groupdate.

### 3rd Party Services

There is an entire ecosystem of Stripe reporting services these days. Here's a few examples:

* [Baremetrics](https://baremetrics.io) gives amazing dashboards and drill-down reports
* [Hookfeed](http://hookfeed.com) builds customer-level analytics and generates email reports
* [FirstOfficer](https://www.firstofficer.io) provides insightful reports that tell you *why* your business is behaving how it is.

All three of these are driven directly from your Stripe event feed and hook into your account via Stripe Connect. To see how to build a service like that, read on to the Marketplaces chapter.
