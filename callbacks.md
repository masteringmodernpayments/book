# Handling Callbacks

Stripe will send your application events as things happen to payments that you initiate and your users' subscriptions. The full list of event types can be found in Stripe's API documentation, but here's a brief list:

* when a charge succeeds or fails
* when a subscription is due to be renewed
* when something about a customer changes
* when a customer disputes a charge

Some of these are more important than others. For example, if you're selling one-off products you probably don't care about the events about charge successes and failures because you're initiating the charge and will know immediately how it went. Those events are more useful for subscription sites where Stripe is handling the periodic billing for you. On the other hand, you always want to know about charge disputes. Too many of those and Stripe may drop your account.

Callback handling is going to be unique to every application. For the example app we're just going to handle disputes for now. We'll add more when we get to the chapter about subscriptions.

## New Controller

We'll need a new controller to handle callbacks:

```ruby
# in app/controllers/callbacks.rb

class CallbacksController < ApplicationController
  skip_before_filter :authenticate_user!
  before_filter :parse_and_validate_event

  def create
  
  end

  private
  def parse_and_validate_event
    @event = JSON.parse(request.body.read)
  end
end
```