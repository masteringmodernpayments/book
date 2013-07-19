[basic-integration-stripe_guide]: https://stripe.com/docs/checkout/guides/rails
[basic-integration-stripe-testing]: https://stripe.com/docs/testing

# The Simplest Stripe Integration

This chapter is going to be a whirlwind integration with Stripe which will give us something to build on for the next few chapters. This is loosely based on Stripe's own [Rails Checkout Guide][basic-integration-stripe_guide].

Remember that this application is going to be selling digital downloads, so we're going to have three actions:

* `buy` - where we create a Sale record and actually charge the customer
* `pickup` - where the customer can download their product
* `download` which will actually send the file to the customer

In addition, we're going to leverage Stripe's excellent management interface which will show us all of our sales as they come in.

## Basic Setup

First, add the Stripe gem to your Gemfile:

```ruby
gem 'stripe', '~> 1.8.3'
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
      @sale = Sale.create!(product_id: product.id, email: params[:email])
      redirect_to pickup_url(guid: @sale.guid)
    rescue Stripe::CardError => e
      # The card has been declined or some other error has occured
      @error = e
      render :new
    end
  end

  def download
    @sale = Sale.where(guid: params[:guid]).first
    raise ActionController::RoutingError.new("Not found") unless @sale

    resp = HTTParty.get(@sale.product.file.url)

    send_data resp.body,
      :filename => File.basename(@sale.product.product.file.url),
      :content_type => resp.headers['Content-Type']
  end

end
```

`#new` is just a placeholder for rendering the corresponding view. The real action happens in `#create` where we look up the product and actually charge the customer. In the last chapter we included a `permalink` attribute in `Product` and we use that here to look up the product, mainly because it'll let us generate nicer-looking URLs. If there's an error we display the `#new` action again. If there's not we redirect to a route named `pickup`. Inside the view for `#show` we include link to `/download` which sends the data to the user from S3.

## Routes

The routes for transactions are pretty simple. Add this to `config/routes.rb`:

```ruby
match '/buy/:permalink' => 'transactions#new',      via: :get,  as: :buy
match '/buy/:permalink' => 'transactions#create',   via: :post, as: :buy
match '/pickup/:guid'   => 'transactions#show',     via: :get,  as: :pickup
match '/download/:guid' => 'transactions#download', via: :get,  as: :download
```

### Why not RESTful URLs?

RESTful URLs are great if you're building a reusable API, but for this example we're writing a pretty simple website and the customer-facing URLs should look good. If you want to use resources, feel free to adjust the examples.

## Views

Time to set up the views. Put this in `app/views/transactions/new.html.erb`:

```rhtml
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

This is a very simple example of a product purchase page with the product's name, description, and a Stripe button using `checkout.js`. Notice that we just drop the description in as html which makes it a risk for cross-site-scripting attacks. Make sure you trust the users you allow to create products. We're rendering the `new` view for the `#create` action, too, so if there's an error we'll display it above the checkout button.

The view for `#pickup` is even simpler, since it basically just has to display the product's download link. In `app/views/transactions/pickup.html.erb`:

```rhtml
<h1>Download <%= @product.name %></h1>

<p>Thanks for buying "<%= @product.name %>". You can download your purchase by clicking the link below.</p>

<p><%= link_to "Download", download_url(@sale) %></p>
```

## Testing

Testing is vitally important to any modern web application, doubly so for applications involving payments. Tests are one of the best ways to make sure your app works the way you think it does.

Manually testing your application is a good first step. Stripe provides <em>test mode keys</em> that you can find in your account settings:

TODO: screenshot of API keys

By using the test mode keys you can run transactions through Stripe with testing credit card numbers and hit not only the happy case, but also a variety of failure cases. Stripe provides [a variety of credit card numbers][basic-integration-stripe-testing] that trigger different failure modes. Here's a small selection:

* `4242 4242 4242 4242`: always succeeds
* `4000 0000 0000 0010`: address failures
* `4000 0000 0000 0101`: cvs check failure
* `4000 0000 0000 0002`: card will always be declined

There are a bunch more failure modes you can check but those are the big ones.

### Automated Tests

Manual testing is all well and good but you should also write repeatable unit and functional tests that you can run as part of your deploy process. This can get a little tricky, though, because you don't really want to be hitting Stripe's API servers with your test requests. They'll be slower and you'll pollute your testing environment with junk data.

Instead, let's use mocks and factories. In `Gemfile`:

```ruby
group :development do
  gem 'mocha', require: false
  gem 'database_cleaner'
end
```

Mocha is a mocking framework that let's us set up fake objects that respond how we want them to. It also allows for expectations, where you declare a method will get called in a certain manner and if it doesn't the test will fail. Database Cleaner cleans out the database between test runs.

Let's set all of this up. In `test/test_helper.rb`:

```ruby
ENV['RAILS_ENV'] = 'test'
require File.expand_path('../../config/environment', __FILE__)
require 'rails/test_help'
require 'database_cleaner'

class ActiveSupport::TestCase

  setup do
    DatabaseCleaner.start
  end

  teardown do
    DatabaseCleaner.clean
  end
end

require 'mocha/setup'
```

Note that Mocha must be required as the very last thing in `test_helper`.

Let's write some tests for `TransactionsController`. In `test/functional/transactions_controller_test.rb`:

```ruby
class TransactionsControllerTest < ActionController::TestCase
  setup do
    Stripe.api_key = 'sk_fake_test_key'
  end

  test "should post create" do
    token = 'tok_123456'
    email = 'foo@example.com'

    product = Product.create(permalink: 'test_product', price: 100)

    charge = mock()
    Stripe::Charge.expects(:create).with({amount: 100, currency: 'usd', card: token, description: email).returns(charge)

    post :create, email: email, stripeToken: token

    assert_not_nil assigns(:sale)
    
    
  end
end
```


## Deploy

Add all the new files to git and commit, then run:

```bash
$ heroku config:add STRIPE_PUBLISHABLE_KEY=pk_your_test_publishable_key STRIPE_SECRET_KEY=sk_your_test_secret_key
$ git push heroku master
```

You should be able to navigate to `https://your-app.herokuapp.com/buy/some_permalink` and click the buy button to buy and download a product.

## Next

In this chapter we built (almost) the simplest Stripe integration possible. In the next chapter we're going to take a detour and talk about PCI and what you have to do to be compliant and secure while using Stripe and Rails.
