# Handling Webhooks

Stripe will send your application events that they call webhooks as things happen to payments that you initiate and your users' subscriptions. The full list of event types can be found in Stripe's API documentation, but here's a brief list:

* when a charge succeeds or fails
* when a subscription is due to be renewed
* when something about a customer changes
* when a customer disputes a charge

Some of these are more important than others. For example, if you're selling one-off products you probably don't care about the events about charge successes and failures because you're initiating the charge and will know immediately how it went. Those events are more useful for subscription sites where Stripe is handling the periodic billing for you. On the other hand, you always want to know about charge disputes. Too many of those and Stripe may drop your account.

Webhook handling is going to be unique to every application. For the example app we're just going to handle disputes for now. We'll add more when we get to the chapter about subscriptions.

## Validating Events

Stripe unfortunately does not sign their events. If they did we could verify that they sent them cryptographically, but because they don't the best thing to do is to take the ID from the POSTed event data and ask Stripe about it directly. Stripe also recommends that we store events and reject IDs that we've seen already to protect against replay attacks. To knock both of these requirements out at the same time, lets make a new model called Event:

```bash
$ rails g model Event \
  stripe_id:string \
  type:string
```

We only need to store the `stripe_id` because we'll be looking up the event using the API every time. Storing the type could be useful later on for reporting purposes.

The model should look like this:

```ruby
class Event < ActiveRecord::Base
  validates_uniqueness_of :stripe_id

  def stripe_event
    Stripe::Event.retrieve(stripe_id)
  end
end
```

## Controller

We'll need a new controller to handle callbacks:

```ruby
# in app/controllers/events.rb

class EventsController < ApplicationController
  skip_before_filter :authenticate_user!
  before_filter :parse_and_validate_event

  def create
    
  end

  private
  def parse_and_validate_event
    event = JSON.parse(request.body.read)
    @event = Event.new(id: event['id'], type: event['type'])
    unless event.save
      render :nothing => true, :status => 400
    end
    @stripe_event = @event.stripe_event
  end
end
```

