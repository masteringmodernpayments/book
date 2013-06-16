[stripe_event]: https://github.com/integrallis/stripe_event

# Handling Webhooks

Stripe will send your application events that they call webhooks as things happen to payments that you initiate and your users' subscriptions. The full list of event types can be found in Stripe's API documentation, but here's a brief list:

* when a charge succeeds or fails
* when a subscription is due to be renewed
* when something about a customer changes
* when a customer disputes a charge

Some of these are more important than others. For example, if you're selling one-off products you probably don't care about the events about charge successes and failures because you're initiating the charge and will know immediately how it went. Those events are more useful for subscription sites where Stripe is handling the periodic billing for you. On the other hand, you always want to know about charge disputes. Too many of those and Stripe may drop your account.

Webhook handling is going to be unique to every application but we can sketch out a general framework that can be used for any application. This is similar to the [stripe_event][] but with some added features. For the example app we're just going to handle disputes for now. We'll add more when we get to the chapter about subscriptions.

## Validating Events

Stripe unfortunately does not sign their events. If they did we could verify that they sent them cryptographically, but because they don't the best thing to do is to take the ID from the POSTed event data and ask Stripe about it directly. Stripe also recommends that we store events and reject IDs that we've seen already to protect against replay attacks. To knock both of these requirements out at the same time, lets make a new model called Event:

```bash
$ rails g model Event \
    stripe_id:string \
    stripe_type:string
```

We only need to store the `stripe_id` because we'll be looking up the event using the API every time. Storing the type could be useful later on for reporting purposes.

The model should look like this:

```ruby
class Event < ActiveRecord::Base
  validates_uniqueness_of :stripe_id

  def stripe_event
    Stripe::Event.retrieve(stripe_id)
  end

  def event_method
    self.stripe_type.gsub('.', '_').to_sym
  end
end
```

## Controller

We'll need a new controller to handle callbacks. In `app/controllers/events.rb`:

```ruby

class EventsController < ApplicationController
  skip_before_filter :authenticate_user!
  before_filter :parse_and_validate_event

  def create
    if self.class.private_method_defined? @event.event_method
      response = self.send(@event.event_method, @event)
      if response
        render json: response.to_json
      else
        render nothing: true
      end
    end
  end

  private
  def parse_and_validate_event
    event = JSON.parse(request.body.read)
    @event = Event.new(id: event['id'], type: event['type'])
    unless event.save
      render :nothing => true, :status => 400
      return
    end
    @stripe_event = @event.stripe_event
  end
end
```

From the top, we skip Devise's `authenticate_user!` before filter because Stripe is obviously not going to have a user for our application. Then, we make our own `before_filter` that actually parses out the event and does the work of preventing replay attacks. If the event doesn't validate for some reason we return 400 and move on. If, on the other hand, it saves correctly we ask Stripe for a fresh copy of the event and then deal with it. All `#create` has to do is return 200 to tell Stripe that we successfully dealt with the event.

But we haven't actually done anything yet. 
