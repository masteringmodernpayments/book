[stripe_guide]: https://stripe.com/docs/checkout/guides/rails

# The Simplest Stripe Integration

This chapter is going to be a whirlwind integration with Stripe. It's going to be simple and nothing you haven't seen before, but it'll give us something to build on for the next few sections. This is loosely based on Stripe's own [Rails Checkout Guide][stripe_guide].

## Basic Setup

First, add the Stripe gem to your Gemfile:

```ruby
gem 'stripe', git: 'https://github.com/stripe/stripe-ruby'
```

And then run `bundle install`.

We'll also need to set up the Stripe keys:

```
# in config/initializers/stripe.rb
Rails.configuration.stripe = {
  publishable_key: ENV['STRIPE_PUBLISHABLE_KEY'],
  secret_key:      ENV['STRIPE_SECRET_KEY'],
}

Stripe.api_key = Rails.configuration.stripe.secret_key
```

Note that we're getting the keys from the environment. This is for two reasons: first, because it lets us easily have different keys for testing and for production; second, and more importantly, it means we don't have to hardcode any potentially dangerous security credentials. Putting the keys directly in your code means that anyone with access to your code base can make Stripe transactions with your account.

## Controller

Next, let's create a new controller named `Transactions` where our Stripe-related logic will live:

```ruby
# in app/controllers/transactions_controller.rb

def TransactionsController < ApplicationController
  skip_before_filter :authenticate_user!, only: [:new, :create]

  def new
  end

  def create
    product = Product.where(id: params[:product_id]).first
    raise ActiveSupport::RoutingError.new("Not found") unless product

    token = params[:stripeToken]

    begin
      charge = Stripe::Charge.create(
        :amount => product.price
        :currency => "usd",
        :card => token,
        :description => params[:email]
      )
      Sale.create!(product_id: product.id, email: params[:email])
      render :success
    rescue Stripe::CardError => e
      # The card has been declined
      error = e
      render :error
    end
  end
end
```

## Views

