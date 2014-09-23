---
discussion_issue: 7
---

[callbacks-stripe_event]: https://github.com/integrallis/stripe_event
[callbacks-PrinceXML]: http://www.princexml.com
[callbacks-DocRaptor]: http://docraptor.com
[callbacks-Docverter]: http://www.docverter.com
[callbacks-stripe-event-docs]: https://stripe.com/docs/api/ruby#events
[callbacks-prawn]: http://prawn.majesticseacreature.com
[callbacks-stripe-receipts]: https://stripe.com/blog/email-receipts

# Handling Webhooks

* One way of handling Stripe events with Ruby metaprogramming
* Testing your event handling
* Learn how to send PDF receipts

---

Stripe tracks every event that happens to the payments, invoices, subscriptions, plans, and recipients that belong to your account. Every time something happens they create an Event object and save it to their database. If you'd like you can iterate over all of these events using [the API][callbacks-stripe-event-docs], but a much more efficient way to deal with them is to register a webhook endpoint with Stripe. Whenever they create a new event, Stripe will POST the information to all of your registered webhooks. Depending on how you respond they may retry later as well. The full list of event types can be found in Stripe's API documentation but here's a brief list:

* when a charge succeeds or fails
* when a subscription is due to be renewed
* when something about a customer changes
* when a customer disputes a charge

Some of these are more important than others. For example, if you're selling one-off products you probably don't care about the events about charge successes and failures because you're initiating the charge and will know immediately how it went. Those events are more useful for subscription sites where Stripe is handling the periodic billing for you. On the other hand, you always want to know about charge disputes. Too many of those and Stripe may drop your account.

We're going to use the [StripeEvent][callbacks-stripe_event] gem to listen for webhooks. It provides an easy to use interface for handling events from Stripe in any way you choose.

## Setup

The first thing to do is to add `stripe_event` to your `Gemfile`:

```ruby
gem 'stripe_event'
```

Then, run `bundle install`.

`StripeEvent` acts as a Rails engine, which means you get everything it offers just by mounting it in your routes. Add this to `config/routes.rb`:

```ruby
mount StripeEvent::Engine => '/stripe-events'
```

In Stripe's management interface you should add a webhook with the address `https://your-app.example.com/stripe-events`.

## Validating Events

Stripe unfortunately does not sign their events. If they did we could verify that they sent them cryptographically, but because they don't the best thing to do is to take the ID from the POSTed event data and ask Stripe about it directly. Stripe also recommends that we store events and reject IDs that we've seen already to protect against replay attacks. To knock both of these requirements out at the same time, let's make a new model called StripeWebhook:

```bash
$ rails g model StripeWebhook \
    stripe_id:string
```

The model should look like this:

```ruby
class StripeWebhook < ActiveRecord::Base
  validates_uniqueness_of :stripe_id
end
```

Notice that we've set up a simple uniqueness validator on `stripe_id`.

When a webhook event comes in `StripeEvent` will ignore everything except the ID that comes from Stripe using what it calls an "event retriever". To actually deduplicate events let's set up a custom event retriever in `config/initializers/stripe_event.rb`:

```ruby
StripeEvent.event_retriever = lambda do |params|
  return nil if StripeWebhook.exists?(stripe_id: params[:id])
  StripeWebhook.create!(stripe_id: params[:id])
  StripeEvent.retrieve(params[:id])
end
```

Returning `nil` from your event retriever tells `StripeEvent` to ignore this particular event. You could use this to do other things. For example, if you are using Stripe Connect and you want to ignore events from certain users you would put that logic here.


## Handling Events

The first thing we should do is handle a dispute which fires when a customer initiates a chargeback. In response to a dispute we send an email to ourselves with all of the details which should be enough to deal with them, since they should be fairly rare. In `config/initializers/stripe_event.rb`:

```ruby
StripeEvent.configure do |events|
  events.subscribe 'charge.dispute.created' do |event|
    StripeMailer.admin_dispute_created(event.data.object).deliver
  end
end
```

In `app/mailers/stripe_mailer.rb`:

```ruby
class StripeMailer < ActionMailer::Base
  default from: 'you@example.com'

  def admin_dispute_created(charge)
    @charge = charge
    @sale = Sale.find_by(stripe_id: @charge.id)
    if @sale
      mail(to: 'you@example.com', subject: "Dispute created on charge #{@sale.guid} (#{charge.id})").deliver
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
StripeEvent.configure do |events|
  # ...

  events.subscribe 'charge.succeeded' do |event|
    charge = event.data.object
    StripeMailer.receipt(charge).deliver
    StripeMailer.admin_charge_succeeded(charge).deliver
  end
end
```

```ruby
class StripeMailer < ActionMailer::Base
  # ...

  def admin_charge_succeeded(charge)
    @charge = charge
    mail(to: 'you@example.com', subject: 'Woo! Charge Succeeded!')
  end

  def receipt(charge)
    @charge = charge
    @sale = Sale.find_by!(stripe_id: @charge.id)
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

Stripe helpfully provides for test-mode webhooks. Assuming you have a publicly accessible staging version of your application, you can set up webhooks to fire when you make test mode transactions. Testing webhooks automatically is pretty simple with `StripeMock`. Let's create a new test in `test/integration/webhooks_test.rb`:

```ruby
class WebhooksTest < ActionDispatch::IntegrationTest
  test 'charge created' do
    event = StripeMock.mock_webhook_event('charge.succeeded', id: 'abc123')

    product = Product.create(price: 100, name: 'foo')
    sale = Sale.create(stripe_id: 'abc123', amount: 100, email: 'foo@bar.com', product: product)

    post '/stripe-events', id: event.id
    assert_equal "200", response.code

    assert_equal 2, StripeMailer.deliveries.length

    assert_equal 'abc123', StripeWebhook.last.stripe_id
  end
end
```

## Effective Emailing

Customers expect to be emailed when things happen with their account, and especially when you're charging them money. It's critical that you send them a few basic transactional emails and Stripe's events make it really easy.

### Events to care about

For a simple app that just sells downloadable things, there aren't that many events that you really need to care about. Your relationship with the customer, as far as their credit card is concerned, is a one time thing. Be sure to send them a receipt when the transaction goes through. Note that Stripe has [built in receipts][callbacks-stripe-receipts] but if you want to modify the content, layout, or attachments, you'll need to do it yourself. Disputes are about the only thing that can cause you pain and we've already dealt with them above.

Subscription businesses, on the other hand, get a rich variety of events from Stripe. For example, in the chapter on Subscriptions we're going to talk about how to use the Invoice events to handle Utility-style billing. One helpful hint: if you use Stripe's subscription trial periods you should ignore the first charge event, since it will be for zero dollars.

### How to generate PDF Receipts

Customers, especially business customers, appreciate getting a PDF receipt along with the email. You make their lives measurably easier by including a file that they can just attach to their expense report, rather than having to go through a convoluted dance to convert your email into something they can use.

There is a paid product named [PrinceXML][callbacks-PrinceXML] that makes excellent PDFs but it is very expensive and not very usable on cloud platforms like Heroku. [DocRaptor][callbacks-DocRaptor] is a paid service that has licensed PrinceXML and provides a nice API. There's also a nice gem named [Prawn][callbacks-prawn] that lets you generate PDFs without going through an HTML intermediary. However, the easiest and cheapest way to generate PDFs that I know of is to use an open-source service that I created named [Docverter][callbacks-Docverter]. All you have to do is generate some HTML and pass it to Docverter's API which then returns a PDF:

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
      You purchased <%= @sale.product.name %> for <%= formatted_price(@sale.amount) %> on <%= @sale.created_at %>.
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
