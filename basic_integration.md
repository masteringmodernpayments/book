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

  def show
    @sale = Sale.where(guid: params[:guid]).first
    raise ActiveSupport::RoutingError.new("Not found") unless @sale
  end

  def create
    product = Product.where(permalink: params[:product]).first
    raise ActiveSupport::RoutingError.new("Not found") unless product

    token = params[:stripeToken]

    begin
      charge = Stripe::Charge.create(
        amount:      product.price,
        currency:    "usd",
        card:        token,
        description: params[:email]
      )
      sale = Sale.create!(product_id: product.id, email: params[:email])
      redirect_to pickup_url(sale)
    rescue Stripe::CardError => e
      # The card has been declined or some other error has occured
      @error = e
      render :new
    end
  end

end
```

`#new` is just a placeholder for rendering the corresponding view. The real action happens in `#create` where we look up the product and actually charge the customer. In the last chapter we included a `permalink` attribute in `Product` and we use that here to look up the product, mainly because it'll let us generate nicer-looking URLs. If there's an error we display the `#new` action again. If there's not, we redirect to a route named `pickup`.

## Routes

The routes for transactions are pretty simple. Add this to `config/routes.rb`:

```ruby
match '/buy/:permalink' => 'transactions#new',    via: :get,  as: :buy
match '/buy/:permalink' => 'transactions#create', via: :post, as: :buy
match '/pickup/:guid'   => 'transactions#show',   via: :get,  as: :pickup
```

Resourceful URLs are great for CRUD-style things and admin views, but they're not that useful

## Views

