# Processing Payments with Background Workers

[background-worker-stripe]: https://stripe.com/docs/tutorials/checkout
[background-worker-guide]: /payment-integration.html
[background-worker-docs]: https://stripe.com/docs/api
[background-worker-sucker_punch]: https://github.com/brandonhilkert/sucker_punch
[background-worker-Celluloid]: https://github.com/celluloid/celluloid/
[background-worker-redis]: http://redis.io
[background-worker-dj]: https://github.com/collectiveidea/delayed_job
[background-worker-sidekiq]: http://sidekiq.org
[background-worker-mperham]: http://www.mikeperham.com
[background-worker-qc]: https://github.com/ryandotsmith/queue_classic

Stripe does everything in their power to make sure the payment process goes smoothly for you and your customers, but sometimes things out of everyone's control can go wrong. This chapter is about making sure that your payment system keeps going in the face of things like connection failures and large bursts of traffic to your application.

## The Problem

Let's take Stripe's example code:

```ruby
Stripe.api_key = ENV['STRIPE_API_KEY']

token = params[:stripeToken]

begin
  charge = Stripe::Charge.create(
    :amount => 1000, # amount in cents, again
    :currency => "usd",
    :card => token,
    :description => "payinguser@example.com"
  )
rescue Stripe::CardError => e
  # The card has been declined
end
```
    
Pretty straight-forward. Using the `stripeToken` that `stripe.js` inserted into your form, create a charge object. If this fails due to a `CardError`, you can safely assume that the customer's card got declined. Behind the scenes, `Stripe::Charge` makes an `https` call to Stripe's API. Typically, this completes almost immediately.

But what if it doesn't? The internet between your server and Stripe's could be slow or down. DNS resolution could be failing. There's a million reasons why this code could take awhile. Browsers typically have around a one minute timeout and application servers like Unicorn usually will kill the request after 30 seconds. That's a long time to keep the user waiting just to end up at an error page.

## The Solution

The solution is to put the call to `Stripe::Charge.create` in a background job. By separating the work that can fail or take a long time from the web request we insulate the user from timeouts and errors while giving our app the ability to retry (if possible) or tell us something failed (if not). 

There's a bunch of different background worker systems available for Rails and Ruby in general, scaling all the way from simple in-process threaded workers with no persistence to external workers persisting jobs to the database or [Redis][background-worker-redis], then even further to message busses like AMQP, which are overkill for what we need to do.

### In-Process

One of the best in-process workers that I've come across is called [Sucker Punch][background-worker-sucker_punch]. Under the hood it uses the actor model to safely use concurrent threads for work processing, but you don't really have to worry about that. It's pretty trivial to use, just include the `SuckerPunch::Worker` module into your worker class, declare a queue using that class, and chuck jobs into it. In `app/workers/banana_worker.rb`:

```ruby
class BananaWorker
  include SuckerPunch::Worker

  def perform(event)
    puts "I am a banana!"
  end
end
```

In `config/initializers/queues.rb`:

```ruby
SuckerPunch.config do
  queue name: :banana_queue, worker: BananaWorker, workers: 10
end
```

Then, in a controller somewhere:

```ruby
SuckerPunch::Queue[:banana_queue].async.perform("hi")
```

The drawback to Sucker Punch, of course, is that if the web process falls over then your jobs evaporate. This will happen, no two ways about it. Errors and deploys will both kill the web process and erase your jobs.

### Database Persistence

The classic, tried-and-true background worker is called [Delayed Job][background-worker-dj]. It's been around since 2008 and is battle tested and production ready. At my day job we use it to process hundreds of thousands of events every day and it's basically fire and forget. It's also easier to use than Sucker Punch. Assuming a class like this:

```ruby
class Banana
  def initialize(size)
    @size = size
  end

  def split
    puts "I am a banana split, #{@size} size!"
  end
end
```

To queue the `#split` method in a background job, all you have to do is:

```ruby
Banana.new('medium').delay.split
```

That is, put a call to `delay` before the call to `split`. Delayed Job will serialize the object, put it in the database, and then when a worker is ready to process the job it'll do the reverse and finally run the `split` method.

To work pending jobs, just run

```bash
$ bundle exec rake jobs:work
```

Delayed Job does have some drawbacks. First, because it stores jobs in the same database as everything else it has to content with everything else. For example, your database serve almost certainly has a limit on the number of connections it can handle, and every worker will require two of them, one for Delayed Job itself and another for any ActiveRecord objects. Second, it can get tricky to backup because you really don't need to be backing up the jobs table. That said, it's relatively simple and straight forward and has the distinct advantage of not making you run any new external services.

Another PostgreSQL-specific database backed worker system is [Queue Classic][background-worker-qc], which leverages some specific features that PostgreSQL provides to workers very efficient. Specifically it uses `listen` and `notify`, the built-in publish/subscribe system, to tell workers when there are jobs to be done so they don't have to poll. It also uses row-level locking to reduce database load and ensure only one worker is working a job at any given time.

### Redis

[Redis][background-worker-redis] bills itself as a "networked data structure server". It's a database server that provides rich data types like lists, queues, sets, and hashes, all while being extremely fast because everything is in-memory all the time. The best Redis-based background worker, in my opinion, is [Sidekiq][background-worker-sidekiq] written by [Mike Perham][background-worker-mperham]. It uses the same actor-based concurrency library under the hood as Sucker Punch, but because it stores jobs in Redis it can also provide things like a beautiful management console and fine-grained control over jobs. The setup is essentially identical to Sucker Punch:

```ruby
class BananaWorker
  include Sidekiq::Worker

  def perform(event)
    puts "I am a banana!"
  end
end
```

Then in a controller:

```ruby
BananaWorker.perform_async("hi")
```

To work jobs, fire up Sidekiq:

```bash
$ bundle exec sidekiq
```

For this example we're going to use Sidekiq. If you'd like to use one of the other job systems described above, or if you already have your own for other things, it should be trivial to change.

First, let's create a job class:

```ruby
class StripeCharger
  include Sidekiq::Worker

  def perform(guid)
    ActiveRecord::Base.connection_pool.with_connection do
      sale = Sale.where(guid: guid).first
      return unless sale
      sale.process!
    end
  end
end
```

Again, pretty straightforward. Sidekiq will create an instance of your job class and call `#perform` on it with a hash of values that you pass in to the queue, which we'll get to in a second. We look up the relevant `Sale` record and tell it to process using the state machine event we set up earlier using `AASM`.

To actually get `StripeCharger` in the loop we have to call it from an `after_create` hook.

```ruby
class Sale < ActiveRecord::Base
  #...

  after_create :queue_charge

  def queue_charge
    StripeCharger.perform_async(guid)
  end
end
```

Now, in the TransactionsController, all we have to do is create the `Sale` record:

```ruby
class TransactionsController < ApplicationController

  def create
    product = Product.where(permalink: params[:permalink]).first
    raise ActionController::RoutingError.new("Not found") unless product

    token = params[:stripeToken]

    sale = Sale.new do |s|
      s.amount = product.price,
      s.product_id = product.id,
      s.stripe_token = token,
      s.email = params[:email]
    end

    if sale.save
      render json: { guid: sale.guid }
    else
      render json: { error: sale.errors.full_messages.join(" ") }, status: 400
    end
  end
  
  def status
    sale = Sale.find(params[:guid])
    raise ActionController::RoutingError.new('not found') unless sale

    render json: { status: sale.state }
  end
end
```

The `create` method creates a new `Sale` record which queues the transaction to be processed by `StripeCharger`. The `status` method simply looks up the transaction and spits back some JSON. To actually process the form we have something like this, which includes the call to `stripe.js`:

```javascript
// Capture the submit event, call Stripe, and start a spinner
$('#payment-form').submit(function(event) {
  var form = $(this);
  form.find('button').prop('disabled', true);
  Stripe.createToken(form, stripeResponseHandler);
  $('#spinner').show();
  return false;
});

// Handle the async response from Stripe. On success,
// POST the form data to the create action and start
// polling for completion. On error, display the error
// to the customer.
function stripeResponseHandler(status, response) {
  var form = $('#payment-form');
  if (response.error) {
    showError(response.error.message);
  } else {
    var token = response.id;
    form.append($('<input type="hidden" name="stripeToken">').val(token));
    $.ajax({
      type: "POST",
      url: "/buy/<%= permalink %>",
      data: $('#payment-form').serialize(),
      success: function(data) { console.log(data); poll(data.guid) },
      error: function(data) { console.log(data); showError(data.responseJSON.error) }
    });
  }
}

// Recursively poll for completion.
function poll(guid) {
  $.get("/status/" + guid, function(data) {
    if (data.status === "finished") {
      window.location = "/pickup/" + guid;
    } else if (data.status === "error") {
      showError(data.error)
    } else {
      setTimeout(function() { poll(guid) }, 500);
    }
  });
}

function showError(error) {
  var form = $('#payment-form');
  form.find('#payment-errors').text(error);
  form.find('#payment-errors').show();
  form.find('button').prop('disabled', false);
  form.find('#spinner').hide();
}
```
    
Putting the call to `Stripe::Charge` in a background job and having the client poll eliminates a whole class of problems related to network failures and insulates you from problems in Stripe's backend. If charges don't go through we just report that back to the user and if the job fails for some other reason Sidekiq will retry until it succeeds.
