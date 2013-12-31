[initial-app-devise]: https://github.com/plataformatec/devise
[initial-app-heroku]: https://www.heroku.com
[initial-app-postgresql]: http://www.postgresql.org
[initial-app-toolbelt]: https://toolbelt.heroku.com
[initial-app-paperclip]: https://github.com/thoughtbot/paperclip
[initial-app-mandrill]: http://mandrill.com
[initial-app-postgres-tutorial]: http://www.moncefbelyamani.com/how-to-install-postgresql-on-a-mac-with-homebrew-and-lunchy/
[basic-integration-stripe_guide]: https://stripe.com/docs/checkout/guides/rails
[basic-integration-stripe-testing]: https://stripe.com/docs/testing
[basic-integration-heroku-vars]: https://devcenter.heroku.com/articles/config-vars

# Basic Integration

In this chapter we're going to create a simple Rails application so we have something to work with for later chapters. All of the rest of the examples in the guide will be based on this app.

Our app will sell downloadable products. Users will be able to create products and customers will be able to buy them, and we'll keep track of sales so we can do reporting later. Customers will be able to come back and download their purchases multiple times. We'll need three models:

* `Product`, representing a product that we're going to be selling. 
* `User`, for logging in and managing products
* `Sale`, to represent each individual customer purchase

## Boilerplate

Let's create an initial application:

```bash
$ rails new sales --database postgresql
$ cd sales
$ createuser -s sales
$ rake db:create
$ rake db:migrate
$ rake test
```

I'm going to use [PostgreSQL][initial-app-postgresql] for the example app because that's what I know best, it's what [Heroku][initial-app-heroku] provides for free, and it's what I suggest to everyone who asks. If you're using a Mac and don't have PostgreSQL installed, [this][initial-app-postgres-tutorial] is an excellent tutorial. If you want to use a different database, feel free to substitute. Any `ActiveRecord`-compatible database will do fine.

## Authentication

We're going to want to be able to authenticate users who can add and manage products and view sales. The example is going to use a gem named [Devise][initial-app-devise] which handles everything user-related out of the box. Add it to your `Gemfile`:

```ruby
gem 'devise', '~> 3.0.0.rc'
```

then run bundler and set up Devise:

```bash
$ bundle install
$ rails generate devise:install
```

At this point you have to do some manual configuration. Add this to `config/environments/development.rb`:

```ruby
config.action_mailer.default_url_options = {
  :host => 'localhost:3000'
}
```

This to `config/routes.rb`:

```ruby
root :to => 'products#index'
```

and this in `app/views/layouts/application.html.erb` right after the `body` tag:

```erb
<% flash.each do |type, msg| %>
  <%= content_tag :p, msg, class: type %>
<% end %>
```

Now, let's create a User model for Devise to work with:

```bash
$ rails generate devise User
$ rake db:migrate
```

Open up `app/controllers/application_controller.rb` and add this line which will secure everything by default:

```ruby
before_action :authenticate_user!
```

You'll need to create a user so you can actually log in to the site. Fire up `rails console` and type:

```ruby
User.create!(
  email:                 'you@example.com',
  password:              'password',  # has to be at least 8 characters
  password_confirmation: 'password'
)
```

## Models

Our sales site needs something to sell, so let's create a product model:

```bash
$ rails g scaffold Product \
    name:string \
    permalink:string \
    description:text \
    price:integer \
    user:references
$ rake db:migrate
```

`name` and `description` will be displayed to the customer, `permalink` and `file` will be used later. Open up `app/models/product.rb` and change it to look like this:

```ruby
class Product < ActiveRecord::Base
  has_attached_file :file

  belongs_to :user
end
```

Note the `has_attached_file`. We're using [Paperclip][initial-app-paperclip] to attach the downloadable files to the product record. Let's add it to `Gemfile`:

```ruby
gem 'paperclip', '~> 3.5.1'
```

And `bundle install` again to get Paperclip installed.

Now we need to generate the migration so paperclip has a place to keep the file metadata:

```bash
$ rails generate paperclip product file
```

We should add an upload button to the Product edit form as well. In `app/views/products/_form.html.erb` inside the `form_for` below the other fields:

```rhtml
<div class="field">
  <%= f.label :file %><br />
  <%= f.file_field :file %>
</div>
```

We also need to populate the `user` reference. In `ProductsController#create`:

```ruby
def create
  @product = Product.new(product_params)
  @product.user = current_user

  respond_to do |format|
    if @product.save
      format.html {
        redirect_to @product,
          notice: 'Product was successfully created.'
      }
      format.json {
        render json: @product,
          status: :created,
          location: @product
      }
    else
      format.html { render 'new' }
      format.json {
        render json: @product.errors,
          status: :unprocessable_entity
      }
    end
  end
end
```

We should also define `product_params` in `ProductsController` toward the bottom. Note that we include the `file` attribute for Paperclip:

```ruby
private
def product_params
  params.require(:product).permit(:description, :name, :permalink, :price, :file)
end
```

We don't allow the `user_id` because we're setting it explicitly to `current_user`.

Our app needs a way to track product sales. Let's make a Sale model too.

```bash
$ rails g scaffold Sale \
    email:string \
    guid:string \
    product:references
$ rake db:migrate
```

Open up `app/models/sale.rb` and make it look like this:

```ruby
class Sale < ActiveRecord::Base
  belongs_to :product

  before_create :populate_guid

  private
  def populate_guid
    self.guid = SecureRandom.uuid()
  end
end
```

We're using a GUID here so that when we eventually allow the user to look at their transaction they won't see the `id`, which means they won't be able to guess the next ID in the sequence and potentially see someone else's transaction. We should also add the relationship to `Product`:

```ruby
class Product < ActiveRecord::Base
  has_many :sales

  validates_numericality_of :price,
    greater_than: 49,
    message: "must be at least 50 cents"
end
```

## Deploying

[Heroku][initial-app-heroku] is the fastest way to get a Rails app deployed into a production environment so that's what we're going to use throughout the guide. If you already have a deployment system for your application by all means use that. First, download and install the [Heroku Toolbelt][initial-app-toolbelt] for your platform. Make sure you `heroku login` to set your credentials.

We'll need to add one more thing, since Rails' asset pipeline doesn't play well with Heroku. Add this to `Gemfile` and run `bundle install` one more time:

```ruby
gem 'rails_12factor', group: :production
```

Next, create an application and deploy the example code to it:

```bash
$ git init
$ git add .
$ git commit -m 'Initial commit'
$ heroku create
$ git push heroku master
$ heroku run rake db:migrate
$ heroku run console # create a user
$ heroku restart web
$ heroku open
```

We'll need to set a few more config options to make our site usable on Heroku. First, we need to set up an outgoing email server and configure `ActionMailer` to use it. Let's add the [Mandrill][initial-app-mandrill] addon:

```bash
$ heroku addons:add mandrill:starter
```

<span class="break"></span>

Now configure it in `config/environments/production.rb`:

```ruby
config.action_mailer.delivery_method = :smtp
config.action_mailer.smtp_settings = {
  address:        'smtp.mandrillapp.com',
  port:           587,
  username:       ENV['MANDRILL_USERNAME'],
  password:       ENV['MANDRILL_APIKEY'],
  domain:         'heroku.com',
  authentication: :plain
}
config.action_mailer.default_url_options = {
  :host => 'your-app.herokuapp.com'
}
```

Mandrill is made by the same folks that make MailChimp. It's reliable, powerful, and cost effective. They give you 12,000 emails per month for free to get started. I use it for all of my applications. Note also that we configure the `default_url_options` here again for ActionMailer. This is what Devise uses to generate links inside emails, so it's pretty important to get it right.

We also need to set up Paperclip to save uploaded files to S3 instead of the local file system. On Heroku your processes live inside what they call a *dyno* which is just a lightweight Linux virtual machine with your application code inside. Each dyno has an *ephemeral filesystem* which gets erased at least once every 24 hours, thus the need to push uploads somewhere else. Paperclip makes this pretty painless. You'll need to add another gem to your Gemfile:

```ruby
gem 'aws-sdk'
```

and then configure Paperclip to use it in `config/environments/production.rb`:

```ruby
config.paperclip_defaults = {
  storage: :s3,
  s3_credentials: {
    bucket: ENV['AWS_BUCKET'],
    access_key_id: ENV['AWS_ACCESS_KEY_ID'],
    secret_access_key: ENV['AWS_SECRET_ACCESS_KEY']
  }
}
```

Just [set those config variables with Heroku][basic-integration-heroku-vars], `bundle install`, and then commit and push up to Heroku.

You should see a login prompt from Devise. Go ahead and login and create a few products. We'll get to buying and downloading in the next section.

## The Simplest Stripe Integration

Now we're going to do a whirlwind Stripe integration, loosely based on Stripe's own [Rails Checkout Guide][basic-integration-stripe_guide].

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

Stripe.api_key = \
  Rails.configuration.stripe[:secret_key]
```

Note that we're getting the keys from the environment. This is for two reasons: first, because it lets us easily have different keys for testing and for production; second, and more importantly, it means we don't have to hardcode any potentially dangerous security credentials. Putting the keys directly in your code means that anyone with access to your code base can make Stripe transactions with your account.

## Controller

Next, let's create a new controller named `Transactions` where our Stripe-related logic will live:

In `app/controllers/transactions_controller.rb`:

```ruby
class TransactionsController < ApplicationController
  skip_before_action :authenticate_user!,
    only: [:new, :create]

  def new
    @product = Product.find_by!(
      permalink: params[:permalink]
    )
  end

  def pickup
    @sale = Sale.find_by!(guid: params[:guid])
    @product = @sale.product
  end

  def create
    product = Product.find_by!(
      permalink: params[:permalink]
    )

    token = params[:stripeToken]

    begin
      charge = Stripe::Charge.create(
        amount:      product.price,
        currency:    "usd",
        card:        token,
        description: params[:email]
      )
      @sale = product.sales.create!(
        email:      params[:email]
      )
      redirect_to pickup_url(guid: @sale.guid)
    rescue Stripe::CardError => e
      # The card has been declined or
      # some other error has occured
      @error = e
      render :new
    end
  end

  def download
    @sale = Sale.find_by!(guid: params[:guid])

    resp = HTTParty.get(@sale.product.file.url)

    filename = @sale.product.file.url
    send_data resp.body,
      :filename => File.basename(filename),
      :content_type => resp.headers['Content-Type']
  end

end
```

`#new` is just a placeholder for rendering the corresponding view. The real action happens in `#create` where we look up the product and actually charge the customer. Note that we hardcode `usd` as the currency. If you have a Stripe account in a different country you'll want to provide your country's currency code here.

In the last chapter we included a `permalink` attribute in `Product` and we use that here to look up the product, mainly because it'll let us generate nicer-looking URLs. If there's an error we display the `#new` action again. If there's not we redirect to a route named `pickup`. Inside the view for `#pickup` we include link to `/download` which sends the data to the user from S3.

We get the data from S3 using a gem named `HTTParty`. Let's add it to the Gemfile:

```ruby
gem 'httparty'
```

## Routes

The routes for transactions are pretty simple. Add this to `config/routes.rb`:

```ruby
get  '/buy/:permalink', to: 'transactions#new',      as: :show_buy
post '/buy/:permalink', to: 'transactions#create',   as: :buy
get  '/pickup/:guid',   to: 'transactions#pickup',   as: :pickup
get  '/download/:guid', to: 'transactions#download', as: :download
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
  <script src="https://checkout.stripe.com/v2/checkout.js"
    class="stripe-button"
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

This is a very simple example of a product purchase page with the product's name, description, and a Stripe button using `checkout.js`. Checkout puts a simple button on your page that pops up a small overlay onto your page where the user puts in their credit card information. Stripe automatically processes the card information into a single use token while handling errors for you. When all of that is done `checkout.js` will submit the surrounding form to your server, taking care to strip out sensitive information. It's a convenient way to collect card information if you don't want to go to the trouble of making your own custom form, which we'll talk about in a later chapter.

Notice that we just drop the description in as html which makes it a risk for cross-site-scripting attacks. Make sure you trust the users you allow to create products. We're rendering the `new` view for the `#create` action, too, so if there's an error we'll display it above the checkout button.

The view for `#pickup` is even simpler, since it basically just has to display the product's download link. In `app/views/transactions/pickup.html.erb`:

```rhtml
<h1>Download <%= @product.name %></h1>

<p>Thanks for buying "<%= @product.name %>". You can download your purchase by clicking the link below.</p>

<p><%= link_to "Download", download_url(guid: @sale.guid) %></p>
```

## Testing

Testing is vitally important to any modern web application, doubly so for applications involving payments. Tests are one of the best ways to make sure your app works the way you think it does.

Manually testing your application is a good first step. Stripe provides <em>test mode keys</em> that you can find in your account settings. By using the test mode keys you can run transactions through Stripe with testing credit card numbers and hit not only the happy case, but also a variety of failure cases. Stripe provides [a variety of credit card numbers][basic-integration-stripe-testing] that trigger different failure modes. Here's a small selection:

* `4242 4242 4242 4242`: always succeeds
* `4000 0000 0000 0010`: address failures
* `4000 0000 0000 0101`: cvs check failure
* `4000 0000 0000 0002`: card will always be declined

There are a bunch more failure modes you can check but those are the big ones. Make sure to manually run your test through at least these failure cases. You'll catch bugs you wouldn't think to test for and you'll actually be interacting with Stripe's API, which you won't be in your automated tests.

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
ENV['RAILS_ENV'] ||= 'test'
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

Let's write a test for `TransactionsController`. In `test/functional/transactions_controller_test.rb`:

```ruby
class TransactionsControllerTest < ActionController::TestCase
  setup do
    Stripe.api_key = 'sk_fake_test_key'
  end

  test "should post create" do
    token = 'tok_123456'
    email = 'foo@example.com'

    product = Product.create(
      permalink: 'test_product',
      price:     100
    )

    Stripe::Charge.expects(:create).with({
      amount:      100,
      currency:    'usd',
      card:        token,
      description: email
    }).returns(mock)

    post :create, email: email, stripeToken: token

    assert_not_nil assigns(:sale)
    assert_equal product.id, assigns(:sale).product_id
    assert_equal email, assigns(:sale).email
  end
end
```

The very first thing we do is set a fake Stripe API key. If for some reason we hit Stripe during our test run it will fail immediately and we'll know where else we have to mock. In the test itself, we set up an expectation on `Stripe::Charge.create` with the arguments that the controller will pass to it and returning a mock object. Then, we `POST` at the controller and assert some things about the created `Sale` object. The underlying theory here is that in these tests we don't care what Stripe does under the covers with the data we pass it, we just care that our controller method is doing the right thing based on what the API returns.

## Deploy

Add all the new files to git and commit, then run:

```bash
$ heroku config:add \
    STRIPE_PUBLISHABLE_KEY=pk_test_publishable_key \
    STRIPE_SECRET_KEY=sk_test_secret_key
$ git push heroku master
```

You should be able to navigate to `https://your-app.herokuapp.com/buy/some_permalink` and click the buy button to buy and download a product.

## Next

In this chapter we built (almost) the simplest Stripe integration possible. In the next chapter we're going to take a detour and talk about PCI and what you have to do to be compliant and secure while using Stripe and Rails.
