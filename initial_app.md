[initial-app-devise]: https://github.com/plataformatec/devise
[initial-app-heroku]: https://www.heroku.com
[initial-app-postgresql]: http://www.postgresql.org
[initial-app-toolbelt]: https://toolbelt.heroku.com
[initial-app-paperclip]: https://github.com/thoughtbot/paperclip
[initial-app-mandrill]: http://mandrill.com

# Initial Application

In this chapter we're going to create a simple rails application so we have something to work with for later chapters. All of the rest of the examples in the guide will be based on this app.

Our app will sell downloadable products. Users will be able to create products and customers will be able to buy them, and we'll keep track of sales so we can do reporting later. Customers will be able to come back and download their purchases multiple times. We'll need three models:

* `Product`, representing a product that we're going to be selling. 
* `User`, for logging in and managing products
* `Sale`, to represent each individual customer purchase

## Boilerplate

Let's create an initial application:

```bash
$ rails new sales --database postgresql --test-framework=rspec
$ cd sales
$ createuser -s sales
$ rake db:setup
$ rake db:migrate
$ rake test
```

I'm going to use [PostgreSQL][initial-app-postgresql] for the example app because that's what I know best, it's what [Heroku][initial-app-heroku] provides for free, and it's what I suggest to everyone who asks. If you want to use a different database, feel free to substitute. Any `ActiveRecord`-compatible database will do fine.

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
config.action_mailer.default_url_options = { :host => 'localhost:3000' }
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
User.create!(email: 'you@example.com', password: 'password', password_confirmation: 'password')
```

## Models

Our sales site needs something to sell, so let's create a product model:

```bash
$ roails g scaffold Product name:string permalink:string description:text price:integer user:references
$ rake db:migrate
```

`name` and `description` will be displayed to the customer, `permalink` and `file` will be used later. Open up `app/models/product.rb` and change it to look like this:

```ruby
class Product < ActiveRecord::Base
  has_attached_file :file

  belongs_to :user
end
```

We're using [Paperclip][initial-app-paperclip] to attach the downloadable files to the product record. Let's add it to `Gemfile`:

```ruby
gem 'paperclip', '~> 3.0'
```

Now we need to generate the migration so paperclip has a place to keep the file metadata:

```bash
$ rails generate paperclip product file
```

Our app needs a way to track product sales. Let's make a Sale model too.

```bash
$ rails g scaffold Sale email:string guid:string product_id:integer
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

We're using a GUID here so that when we eventually allow the user to look at their transaction they won't see the `id`, which means they won't be able to guess the next ID in the sequence and potentially see someone else's transaction.

## Deploying

[Heroku][initial-app-heroku] is the fastest way to get a Rails app deployed into a production environment so that's what we're going to use throughout the guide. If you already have a deployment system for your application by all means use that. First, download and install the [Heroku Toolbelt][initial-app-toolbelt] for your platform. Make sure you `heroku login` to set your credentials.

Next, create an appliation and deploy the example code to it:

```bash
$ heroku create
$ git init
$ git add .
$ git commit -m 'Initial commit'
$ git push heroku master
$ heroku run rake db:migrate
$ heroku run console # create a new user like we did before in the local console
$ heroku restart web # restart the web dyno to pick up the database changes
$ heroku open
```

We'll need to set a few more config options to make our site usable on Heroku. First, we need to set up an outgoing email server and configure `ActionMailer` to use it. Let's add the [Mandrill][initial-app-mandrill] addon:

```bash
$ heroku addons:add mandrill:starter
```

<span class="pagebreak"></span>

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
```

Mandrill is made by the same folks that make MailChimp. It's reliable, powerful, and cost effective. They give you 12,000 emails per month for free to get started. I use it for all of my applications.

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
    secret_access_key: ENV['AWS_SECRET_ACCESS_KEY'],
  }
}
```

Just set those config variables with Heroku, `bundle install`, and then commit and push up to Heroku.

You should see a login prompt from Devise. Go ahead and login and create a few products. We'll get to buying and downloading in the next chapter.

## Next

Now we have a very simple application which will be enough to get going. We have things to sell and a way to track sales, as well as authentication so not just anybody can come muck with our stuff. Next, we'll run through the simplest Stripe integration and actually sell some stuff.

