# Initial Application

    $ rails new sales --database postgresql --test-framework=rspec
    $ cd sales
    $ bundle exec rails s

    $ createuser sales
    $ createdb -O sales sales_development
    $ createdb -O sales sales_test
