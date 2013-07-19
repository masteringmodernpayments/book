[callbacks-stripe_event]: https://github.com/integrallis/stripe_event
[callbacks-PrinceXML]: http://www.princexml.com
[callbacks-DocRaptor]: http://docraptor.com
[callbacks-Docverter]: http://www.docverter.com
[callbacks-stripe-event-docs]: https://stripe.com/docs/api/ruby#events

# Handling Webhooks

Stripe tracks every event that happens to the payments, invoices, subscriptions, plans, and recipients that belong to your account. Every time something happens they create an Event object and save it to their database. If you'd like you can iterate over all of these events using [the API][callbacks-stripe-event-docs], but a much more efficient way to deal with them is to register a webhook endpoint with Stripe. Whenever they create a new event, Stripe will POST the information to all of your registered webhooks. Depending on how you respond they may retry later as well. The full list of event types can be found in Stripe's API documentation but here's a brief list:

* when a charge succeeds or fails
* when a subscription is due to be renewed
* when something about a customer changes
* when a customer disputes a charge

Some of these are more important than others. For example, if you're selling one-off products you probably don't care about the events about charge successes and failures because you're initiating the charge and will know immediately how it went. Those events are more useful for subscription sites where Stripe is handling the periodic billing for you. On the other hand, you always want to know about charge disputes. Too many of those and Stripe may drop your account.

Webhook handling is going to be unique to every application but we can sketch out a general framework that can be used for any application. This will be similar to the [stripe_event][callbacks-stripe_event] gem, but instead of using notifications it uses a simple metaprogramming system.

## Validating Events

Stripe unfortunately does not sign their events. If they did we could verify that they sent them cryptographically, but because they don't the best thing to do is to take the ID from the POSTed event data and ask Stripe about it directly. Stripe also recommends that we store events and reject IDs that we've seen already to protect against replay attacks. To knock both of these requirements out at the same time, lets make a new model called Event:

```bash
$ rails g model StripeEvent \
    stripe_id:string \
    stripe_type:string
```

We need to store the `stripe_id` because we'll be looking up the event using the API every time. We'll use the type later for figuring out what handler method to call.

The model should look like this:

```ruby
class StripeEvent < ActiveRecord::Base
  validates_uniqueness_of :stripe_id

  def event
    Stripe::Event.retrieve(stripe_id)
  end
end
```

## Controller

We'll need a new controller to handle callbacks. In `app/controllers/stripe_events_controller.rb`:

```ruby

class StripeEventsController < ApplicationController
  skip_before_filter :authenticate_user!
  before_filter :parse_and_validate_event

  def create
    if self.class.private_method_defined? event_method
      self.send(event_method, @event)
    end
    render nothing: true
  end

  private

  def event_method
    "stripe_#{@event.stripe_type.gsub('.', '_')}".to_sym
  end

  def parse_and_validate_event
    @event = StripeEvent.new(id: params[:id], type: params[:type])

    unless @event.save
      if @event.valid?
        render nothing: true, status: 400 # valid event, try again later
      else
        render nothing: true # invalid event, move along
      end
      return
    end
  end
end
```

We skip Devise's `authenticate_user!` before filter because Stripe is obviously not going to have a user for our application. Then, we make our own `before_filter` that actually parses out the event and does the work of preventing replay attacks. This involves just creating a `StripeEvent` record, which validates that the `stripe_id` is unique. If the event doesn't validate we return 400 and move on. If everything goes smoothly we ask Stripe for a fresh copy of the event and then deal with it.

`create` is where all the action happens. `event_method` will generate a symbol. If we've defined a private method of that name, call it with the event as the argument. If the handler doesn't throw an exception let Stripe know that we handled it by returning a success code. This setup lets us easily handle the events we care about by defining the appropriate handler while ignoring the noise.

## Handling Events

The first thing we should do is handle a dispute which fires when a customer initiates a chargeback. In response to a dispute we send an email to ourselves with all of the details which should be enough to deal with them, since they should be fairly rare:


```ruby
private
def stripe_charge_dispute_created(event)
  StripeMailer.admin_dispute_created(event).send
end
```

In `app/mailers/stripe_mailer.rb`:

```ruby
class StripeMailer < ActionMailer::Base
  default from: 'you@example.com'

  def admin_dispute_created(event)
    @event = event
    @charge = @event.data.object
    @sale = Sale.where(stripe_id: @charge.id).first
    if sale
      mail(to: 'you@example.com', subject: "Dispute created on charge #{@sale.guid} (#{charge.id})")
    end
  end
end
```

And in `app/views/stripe_mailer/admin_dispute_created.html.erb`:

```rhtml
<html>
  <body>
    <p>Dispute opened on <%= link_to "charge #{@sale.guid}", sale_url(@sale) %></p>
  </body>
</html>
```

Disputes are sad. We should also handle a happy event, like someone buying something. Let's do `charge.succeeded`:

```ruby
private
def stripe_charge_succeeded(event)
  StripeMailer.receipt(event).send
  StripeMailer.admin_charge_succeeded(event).send
end
```

```ruby
class StripeMailer < ActionMailer::Base
  # ...

  def admin_charge_succeeded(event)
    @charge = @event.data.object
    mail(to: 'you@example.com', subject: 'Woo! Charge Succeeded!')
  end

  def receipt(event)
    @charge = @event.data.object
    @sale = Sale.where(stripe_id: @charge.id).first
    mail(to: @sale.email, subject: "Thanks for purchasing #{@sale.product.name}")
  end
end
```

In `app/views/admin_charge_succeeded.html.erb`:

```rhtml
<html>
  <body>
    <p>Charge succeeded! Amount: <%= @sale.amount %> </p>
    <p><%= link_to @sale.guid, sale_url(@sale) %></p>
  </body>
</html>
```

In response to a charge succeeding we send a receipt to the customer and an alert to ourselves so we can get that sweet dopamine hit when the email alert sound dings. We'll show the body of the receipt email below.

Many of the events that Stripe sends are for dealing with subscriptions. For example, Stripe will let you know when they're about to initiate a periodic charge and give you the opportunity to add extra things to the invoice, like monthly add-ons or overage billing. We'll talk more about this in the chapter on Subscriptions.

## Testing Events

Stripe helpfully provides for test-mode webhooks. Assuming you have a publically accessible version of your site, you can set up webhooks to fire when you make test mode transactions. If you forget to set up a live mode webhook, Stripe will also send live mode events to your test hook. This can be either good or bad, depending on how complicated you like your life.

Testing webhooks automatically is pretty simple, assuming you have the mocking set up like we talked about in Chapter 3. The test setup for `StripeEventsController` would look something like this:

```ruby
class StripeEventsControllerTest < ActionController::TestCase

  setup do
    Stripe.api_key = 'sk_fake_api_key'
  end

  test 'charge created' do
    event_id = 'fake_event_id'

    product = Product.create(price: 100, name: 'foo')
    sale = Sale.create(stripe_id: 'abc123', amount: 100, email: 'foo@bar.com', product: product)

    mock_event = mock
    mock_data = mock
    mock_charge = mock

    mock_event.expects(:data).returns(mock_data)
    mock_data.expects(:object).returns(mock_charge)
    mock_charge.expects(:id).returns('abc123').at_least_once
    mock_charge.expects(:amount).returns(100)

    Stripe::Event.expects(:fetch).with(event_id).at_least_once.returns(mock_event)

    post :create, id: event_id, type: 'charge.succeeded'
  end
end
```

There are a few things to note here. First, just like in the tests in Chapter 3 we set up a fake API key so Stripe will tell us right away if we're accidentally hitting their API. Next, we create some testing fixtures to work with and then set up a slew of mocks and expectations. These expectations effectively act as the assertions in this test, so at the end we just `POST` at the controller.

When setting this endpoint in Stripe's web interface, make sure to use `https://your-app/events.json`, not just `/events`. That way Rails will automatically decode Stripe's JSON data into params we can work with directly.

## Effective Emailing

Customers expect to be emailed when things happen with their account, and especially when you're charging them money. It's critical that you send them a few basic transactional emails and Stripe's events make it really easy.

### Events to care about

For a simple app that just sells downloadable things, there aren't that many events that you really need to care about. Your relationship with the customer, as far as their credit card is concerned, is a one time thing. Be sure to send them a receipt when the transaction goes through. Disputes are about the only thing that can cause you pain and we've already dealt with them above.

Subscription businesses, on the other hand, get a rich variety of events from Stripe. For example, in the chapter on Subscriptions we're going to talk about how to use the Invoice events to handle Utility-style billing. One helpful hint: if you use Stripe's subscription trial periods you should ignore the first charge event, since it will be for zero dollars.

### How to generate PDF Receipts

Customers, especially business customers, appreciate getting a PDF receipt along with the email. You make their lives measurably easier by including a file that they can just attach to their expense report, rather than having to go through a convoluted dance to convert your email into something they can use.

There is a paid product named [PrinceXML][callbacks-PrinceXML] that makes excellent PDFs but it is very expensive and not very usable on cloud platforms like Heroku. [DocRaptor][callbacks-DocRaptor] is a paid service that has licensed PrinceXML and provides a nice API. However, the easiest and cheapest way to generate PDFs that I know of is to use an open-source service that I created named [Docverter][callbacks-Docverter]. All you have to do is generate some HTML and pass it to Docverter's API which then returns a PDF:

In `Gemfile`:

```ruby
gem 'docverter'
```

In `app/mailers/receipt_mailer.rb`:

```ruby
class ReceiptMailer < ActionMailer::Base
  def receipt(sale)
    @sale = sale
    html = render_to_string('receipt_mailer/receipt.html')
    
    pdf = Docverter::Conversion.run do |c|
      c.from = 'html'
      c.to = 'pdf'
      c.content = html
    end

    attachment['receipt.pdf'] = pdf
    mail(to: sale.email_address, subject: 'Receipt for your purchase')
  end
end
```

In `app/views/receipt_mailer/receipt.html.erb`:

```rhtml
<html>
  <body>
    <h1>Receipt</h1>
    <p>
      You purchased <%= @sale.product.name %> for <%= formatted_price(@sale.amount) %> on <%= @sale.created_at.to_f("%Y-%m-%d") %>.
    </p>
    <p>
      <%= link_to "Click here", pickup_url(guid: @sale.guid) %> to download your purchase.
    </p>
    <p>
      Thank you for your purchase!
    </p>
    <p>
      -- Pete
    </p>
  </body>
</html>
```

This will send a PDF copy of the customer's receipt along with the email which they should be able to drop directly into their expense reporting sytem.
