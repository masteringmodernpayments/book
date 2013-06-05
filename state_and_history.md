[aasm]: https://github.com/aasm/aasm

# Transaction Records

So far in our little example app we can buy and sell downloadable products using Stripe. However, the only way we can know how much money our store has made is by asking Stripe. We can't easily ask our database for reporting purposes becase we're just tracking sales as one-off events. We also have to trust Stripe to not mess up, which when you're dealing with financial concerns can be a lot to ask. It would be better if we could keep our own records and then reconcile them with Stripe later.

## State Machines

Ideally, we'd like to be able to trace each sale through from initialization to completion, including purchase, refunds, errors, etc. One step along the way is to track the state of each transaction using a *state machine*. A state machine is simply a formal definition of what states an object can be in and the transitions that can happen to get it between states. TODO: think of an example.

There's an excellent gem named [aasm][] that makes implementing state machines for ActiveRecord objects very easy. Let's make a new record named **Transaction** to store our state machine:

```bash
$ rails g model Transaction amount:integer state:string stripe_id:string stripe_token:string card_last4:string card_expiration:string error:text
```

Now, add `aasm` to your Gemfile:

```ruby
gem 'aasm'
```

Our state machine will have four possible states:

* *pending* means we just created the record
* *processing* means we're in the middle of processing
* *finished* means we're done talking to Stripe and everything went well
* *error* means that we're done talking to Stripe and there was an error

We'll also have a few different events for the transaction: `process`, `finish`, and `error`. Let's describe this using `aasm`:

```ruby
class Transaction < ActiveRecord::Base
  include AASM

  aasm do
    state :pending, initial: true
    state :processing
    state :finished
    state :error

    event :process do
      transitions from: :pending, to: :processing
    end

    event :finish do
      transitions from: :processing, to: :finished
    end

    event :error do
      transitions from: :processing, to: :error
    end
  end
end

