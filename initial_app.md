[devise]: https://github.com/plataformatec/devise
[heroku]: https://www.heroku.com
[postgresql]: http://www.postgresql.org
[toolbelt]: https://toolbelt.heroku.com

todo yet:
* display sale to user
* add a download URL to the product and allow the user to download it

# Initial Application

In this chapter we're going to create a very simple rails application so we have something to work with for later chapters. All of the rest of the examples in the guide will be based on this app. You can either follow along with the instructions or use the app in the `sales` directory in the example code.

A note on versions. The example app will be using Rails 3.2.13 and PostgreSQL 9.2.

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

I'm going to use [PostgreSQL][postgresql] for the example app because that's what I know best, it's what [Heroku][heroku] provides for free, and it's what I suggest to everyone who asks. If you want to use a different database, feel free to substitute. Any `ActiveRecord`-compatible database should be sufficient.

## Authentication

Eventually we're going to want to be able to authenticate users and admins. The example is going to use a gem named [Devise][devise] which handles everything user-related out of the box. Add it to your `Gemfile`:

```ruby
gem 'devise', '~> 2.2.4'
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
<p class="notice"><%= notice %></p>
<p class="alert"><%= alert %></p>
```

Also, you'll want to delete `public/index.html` because it gets in Devise's way.

Now, let's create a User model for devise to work with:

```bash
$ rails generate devise User
$ rake db:migrate
```

Open up `app/controllers/application_controller.rb` and add this line, which will secure everything by default:

```ruby
before_filter :authenticate_user!
```

You'll need to a user so you can actually log in to the site. Fire up `rails console` and type:

```ruby
User.create!(email: 'you@example.com', password: 'password', password_confirmation: 'password')
```

## Models

Our sales site needs something to sell, so let's create a product model:

```bash
$ rails g scaffold Product name:string permalink:string description:text price:integer user_id:integer download_url:text
$ rake db:migrate
```

`name` and `description` will actually get displayed to the customer, `permalink` and `download_url` will be used later. Open up `app/models/product.rb` and change it too look like this:

```ruby
class Product < ActiveRecord::Base
  attr_accessible :description, :name, :permalink, :price, :user_id, :download_url

  belongs_to :user
end
```

The sales site needs a way to track, you know, sales. Let's make a Sale model too.

```bash
$ rails g scaffold Sale email:string guid:string uct_id:integer
$ rake db:migrate
```

Open up `app/models/sale.rb` and make it look like this:

```ruby
class Sale < ActiveRecord::Base
  attr_accessible :email, :product_id

  belongs_to :product

  before_save :populate_guid

  def populate_guid
    if new_record?
      self.guid = SecureRandom.guid()
    end
  end
end
```

We're using a GUID here so that when we eventually allow the user to look at their transaction they won't see the `id`, which means they won't be able to guess the next ID in the sequence and potentially see someone else's transaction.

## Deploying

[Heroku][heroku] is bar-none the fastest way to get a Rails app deployed into a production environment, so that's what we're going to use throughout the guide. If you already have a deployment system for your application by all means use that. First, download and install the [Heroku Toolbelt][toolbelt] for your platform. Make sure you `heroku login` to set your credentials.

Next, create an appliation and deploy the example code to it:

```bash
$ heroku create
$ git init .
$ git add .
$ git commit -m 'Initial commit'
$ git push heroku master
$ heroku open
$ heroku run console # create a new user like we did before in the local console
```

## Next

Now we have a very simple application, but it's enough to get going. We have things to sell and a way to track sales, as well as authentication so not just anybody can come muck with our stuff. Next, we'll run through the simplest Stripe integration and actually sell some stuff.

