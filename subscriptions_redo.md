---
discussion_issue: 9
---

# Subscriptions

* Learn how to set up basic subscriptions
* Create composable service objects
* 

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
      customer = Stripe::Customer.create(
        card: token,
        email: user.email,
        plan: plan.stripe_id,
      )

      subscription.stripe_id = customer.id

      subscription.save!

      UserMailer.send_receipt(user.id, plan.id, raw_token)
          if s.errors.empty?

    rescue Stripe::StripeError => e
      subscription.errors[:base] << e.message
    end

    subscription
  end 
end
```

One of the best things about service objects is how easy it is to compose them. We can just use the `CreateUser` service we set up to create a user wherever we want, including in other service objects.

First we create the user and then a `Subscription` object. Next, we actually talk to Stripe. All we have to do is create a `Stripe::Customer` object with the plan, token, and email address of the user. We store the customer ID onto our `Subscription` object for later reference then send a receipt email which will contain a link for the user to set up their password.

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

  <button type="submit">Submit Payment</button>
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

* adding more than one subscription
* user roles (authority gem)
* self-service cancellation, upgrade, downgrade

## Testing

* mocking with stripe mock

## Webhooks and Emails

* interesting events
* testing
* dunning emails

## Plans In-depth

* how to deal with multiple plans (naming scheme)
* upgrading, downgrading, and prorating
* free trials, both with and without card
* usage billing (utility style)

## Reporting

* keeping your db in sync with stripe
* 3rd party services
