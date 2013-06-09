[stripe_guide]: https://stripe.com/docs/checkout/guides/rails

# The Simplest Stripe Integration

This chapter is going to be a whirlwind integration with Stripe. It's going to be simple and nothing you haven't seen before, but it'll give us something to build on for the next few sections. This is loosely based on Stripe's own [Rails Checkout Guide][stripe_guide].

Remember that this application is going to be selling digital downloads, so we're going to have two actions:

* **buy** where we create a Sale record and actually charge the customer,
* **pickup** where the customer can download their product.

## Basic Setup

First, add the Stripe gem to your Gemfile:

```ruby
gem 'stripe', git: 'https://github.com/stripe/stripe-ruby'
```

And then run `bundle install`.

We'll also need to set up the Stripe keys. In `config/initializers/stripe.rb`:

```ruby
Rails.configuration.stripe = {
  publishable_key: ENV['STRIPE_PUBLISHABLE_KEY'],
  secret_key:      ENV['STRIPE_SECRET_KEY'],
}

Stripe.api_key = Rails.configuration.stripe.secret_key
```

Note that we're getting the keys from the environment. This is for two reasons: first, because it lets us easily have different keys for testing and for production; second, and more importantly, it means we don't have to hardcode any potentially dangerous security credentials. Putting the keys directly in your code means that anyone with access to your code base can make Stripe transactions with your account.

## Controller

Next, let's create a new controller named `Transactions` where our Stripe-related logic will live:

In `app/controllers/transactions_controller.rb`:

```ruby
class TransactionsController < ApplicationController
  skip_before_filter :authenticate_user!, only: [:new, :create]

  def new
    @product = Product.where(permalink: params[:permalink]).first
    raise ActionController::RoutingError.new("Not found") unless @product
  end

  def show
    @sale = Sale.where(guid: params[:guid]).first
    raise ActionController::RoutingError.new("Not found") unless @sale
    @product = @sale.product
  end

  def create
    product = Product.where(permalink: params[:permalink]).first
    raise ActionController::RoutingError.new("Not found") unless product

    token = params[:stripeToken]

    begin
      charge = Stripe::Charge.create(
        amount:      product.price,
        currency:    "usd",
        card:        token,
        description: params[:email]
      )
      sale = Sale.create!(product_id: product.id, email: params[:email])
      redirect_to pickup_url(guid: sale.guid)
    rescue Stripe::CardError => e
      # The card has been declined or some other error has occured
      @error = e
      render :new
    end
  end

end
```

`#new` is just a placeholder for rendering the corresponding view. The real action happens in `#create` where we look up the product and actually charge the customer. In the last chapter we included a `permalink` attribute in `Product` and we use that here to look up the product, mainly because it'll let us generate nicer-looking URLs. If there's an error we display the `#new` action again. If there's not we redirect to a route named `pickup`.

## Routes

The routes for transactions are pretty simple. Add this to `config/routes.rb`:

```ruby
match '/buy/:permalink' => 'transactions#new',    via: :get,  as: :buy
match '/buy/:permalink' => 'transactions#create', via: :post, as: :buy
match '/pickup/:guid'   => 'transactions#show',   via: :get,  as: :pickup
```

### Why not RESTful URLs?

RESTful URLs are great if you're building a reusable API, but for this example we're writing a pretty simple website and the customer-facing URLs should look good. If you want to use resources, feel free to adjust the examples.

## Views

Time to set up the views. Put this in `app/views/transactions/new.html.erb`:

```erb
<h1><%= @product.name %></h1>

<%= @product.description.html_safe %>

<% if @error %>
<%= @error %>
<% end %>

<p>Price: <%= formatted_price(@product.price) %></p>

<%= form_tag buy_path(permalink: @product.permalink) do %>
  <script src="https://checkout.stripe.com/v2/checkout.js" class="stripe-button"
           data-key="<%= Rails.configuration.stripe[:publishable_key] %>"
           data-description="<%= @product.name %>"
           data-amount="<%= @product.price %>"></script>
<% end %>
```

Drop the definition for `formatted_price` into `app/helpers/application_helper.rb`:

```ruby
def formatted_price(amount)
  sprintf("$%0.2f", amount / 100.0)
end
```

This is a very simple example of a product purchase page with the product's name, description, and a Stripe button using `checkout.js`. Notice that we just drop the description in as html, so make sure that's locked down. We're rendering this for the `#create` action, too, so if there's an error we'll display it above the checkout button.

The view for `#pickup` is even simpler, since it basically just has to display the product's download link. In `app/views/transactions/pickup.html.erb`:

```erb
<h1>Download <%= @product.name %></h1>

<p>Thanks for buying "<%= @product.name %>". You can download your purchase by clicking the link below.</p>

<p><%= link_to "Download", @product.download_url %></p>
```

## Deploy

Add all the new files to git and commit, then run:

```bash
$ heroku config:add STRIPE_PUBLISHABLE_KEY=pk_your_test_publishable_key STRIPE_SECRET_KEY=sk_your_test_secret_key
$ git push heroku master
```

You should be able to navigate to `https://your-app.herokuapp.com/buy/some_permalink` and click the buy button to buy and download a product.

## Next

In this chapter we built (almost) the simplest Stripe integration possible. In the next chapter we're going to cover why and how to save more information about the transaction to our own database.
