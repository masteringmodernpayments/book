[devise]: https://github.com/plataformatec/devise
[heroku]: https://www.heroku.com
[postgresql]: http://www.postgresql.org

* boilerplate
* authentication
* models

# Initial Application

In this chapter we're going to create a very simple rails application so we have something to work with for later chapters. All of the rest of the examples in the guide will be based on this app. You can either follow along with the instructions or use the app in the `sales` directory in the example code.

A note on versions. The example app will be using Rails 3.2.13 and PostgreSQL 9.2.

## Boilerplate

Let's create an initial application:

    $ rails new sales --database postgresql --test-framework=rspec
    $ cd sales
    $ createuser -s sales
    $ rake db:setup
    $ rake db:migrate
    $ rake test

I'm going to use [PostgreSQL][postgresql] for the example app because that's what I know best, it's what [Heroku][heroku] provides for free, and it's what I suggest to everyone who asks. If you want to use a different database, feel free to substitute. Any `ActiveRecord`-compatible database should be sufficient.

## Authentication

Eventually we're going to want to be able to authenticate users and admins. The example is going to use a gem named [Devise][devise] which handles everything user-related out of the box. Add it to your `Gemfile`:

    gem 'devise', '~> 2.2.4'

then run bundler and set up Devise:

    $ bundle install
    $ rails generate devise:install

At this point you have to do some manual configuration. Essentially you have to configure ActionMailer, routes, and layout. Add this to `config/environments/development.rb`:

    config.action_mailer.default_url_options = { :host => 'localhost:3000' }

This to `config/routes.rb`:

    root :to => 'products#index'

and this in `app/views/layouts/application.html.erb` right after the `body` tag:

    <p class="notice"><%= notice %></p>
    <p class="alert"><%= alert %></p>

Also, you'll want to delete `public/index.html` because it gets in Devise's way.

Now, let's create a User model for devise to work with:
    
    $ rails generate devise User
    $ rake db:migrate

Open up `app/controllers/application_controller.rb` and add this line, which will secure everything by default:

    before_filter :authenticate_user!

You'll need to a user so you can actually log in to the site. Fire up `rails console` and type:

    User.create!(email: 'you@example.com', password: 'password', password_confirmation: 'password')

## Models

Our sales site needs something to sell, so let's create a product model:

    $ rails g scaffold Product name:string permalink:string description:text price:integer user_id:integer
    $ rake db:migrate

`name` and `description` will actually get displayed to the customer, `permalink` will be used later. Open up `app/models/product.rb` and change it too look like this:

    class Product < ActiveRecord::Base
      attr_accessible :description, :name, :permalink, :price, :user_id

      belongs_to :user
    end

The sales site needs a way to track, you know, sales. Let's make a Sale model too.

    $ rails g scaffold Sale email:string guid:string product_id:integer
    $ rake db:migrate

Open up `app/models/sale.rb` and make it look like this:

    class Sale < ActiveRecord::Base
      attr_accessible :email, :guid, :product_id

      belongs_to :product
    end

