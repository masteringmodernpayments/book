# Initial Application

In this chapter we're going to create a very simple rails application so we have something to work with for later chapters. All of the rest of the examples in the guide will be based on this app. You can either follow along with the instructions or use the app in the `sales` directory in the example code.

## Boilerplate

Let's create an initial application:

    $ rails new sales --database postgresql --test-framework=rspec
    $ cd sales
    $ createuser -s sales
    $ bundle exec rake db:setup
    $ bundle exec rake db:migrate
    $ bundle exec rake test

I'm going to use PostgreSQL for the example app because that's what I know best, it's what Heroku provides for free, and it's what I suggest to everyone who asks. If you want to use a different database, feel free to substitute. Any `ActiveRecord`-compatible database should be sufficient.




