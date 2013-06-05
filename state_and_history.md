[aasm]: https://github.com/aasm/aasm

# Transaction Records

So far in our little example app we can buy and sell downloadable products using Stripe. However, the only way we can know how much money our store has made is by asking Stripe. We can't easily ask our database for reporting purposes becase we're just tracking sales as one-off events. We also have to trust Stripe to not mess up, which when you're dealing with financial concerns can be a lot to ask. It would be better if we could keep our own records and then reconcile them with Stripe later.

## State Machines

Ideally, we'd like to be able to trace each sale through from initialization to completion, including purchase, refunds, errors, etc. One step along the way is to track the state of each transaction using a *state machine*. A state machine is simply a formal definition of what states an object can be in and the transitions that can happen to get it between states. TODO: think of an example.

There's an excellent gem named [aasm][] that makes implementing state machines for ActiveRecord objects very easy. Let's add some more fields to `Sale`:

```bash
$ rails g migration AddFieldsToSale state:string stripe_id:string stripe_token:string card_last4:string card_expiration:string card_type:string email:string error:text product_id:integer
```

Now, add `aasm` to your Gemfile:

```ruby
gem 'aasm'
```

Our state machine will have four possible states:

* *pending* means we just created the record
* *processing* means we're in the middle of processing
* *finished* means we're done talking to Stripe and everything went well
* *errored* means that we're done talking to Stripe and there was an error

We'll also have a few different events for the transaction: `process`, `finish`, and `error`. Let's describe this using `aasm`:

```ruby
class Sale < ActiveRecord::Base
  include AASM

  aasm do
    state :pending, initial: true
    state :processing
    state :finished
    state :errored

    event :process, after: :charge_card do
      transitions from: :pending, to: :processing
    end

    event :finish do
      transitions from: :processing, to: :finished
    end

    event :error do
      transitions from: :processing, to: :errored
    end
  end

  def charge_chard
    begin
      charge = Stripe::Charge.create(
        amount: self.amount,
        currency: "usd",
        card: self.stripe_token,
        description: self.email,
      )
      self.update_attributes(
        stripe_id: charge.id,
        card_last4: charge.card.last4
        card_expiration: Date.new(charge.card.exp_year, Charge.card.exp_month, 1),
        card_type: charge.card.type
      )
      self.save!
      self.finish!
    rescue Stripe::Error => e
      self.error = e.message
      self.save!
      self.error!
    end
  end
end
```

Inside the `aasm` block, every state we described earlier gets a `state` declaration, and every event gets an `event` declaration. Notice that the `:pending` state is what the record will be created with. Also, notice that the transition from `:pending` to `:processing` has an `:after` callback declared. After `aasm` updates the `state` property and saves the record it will call the `charge_card` method.

We moved the logic to charge the card from the controller into the model. This adheres to the Fat Model Skinny Controller priciple, where all of the logic lives in the model and the controller just drives it. Let's see what the controller's `create` method looks like now:

```ruby
def create
  product = Product.where(permalink: params[:permalink]).first
  raise ActionController::RoutingError.new("Not found") unless product

  token = params[:stripeToken]
  transaction = Transaction.create(
    amount: product.price,
    email: params[:email],
    stripe_token: token
  )
  transaction.process!
  if transaction.finished?
    sale = Sale.create!(product_id: product.id, email: params[:email])
    redirect_to pickup_url(guid: sale.guid)
  else
    @error = transaction.error
    render :new
  end
end
```

Not too much different. We use the Transaction record to 