# Mastering Modern Payments
## Using Stripe with Rails

* Introduction
  * why stripe?
  * why rails?
  * what we're going to cover
* [Initial app description](/initial_app)
  * products
  * users/admins
* PCI Compliance Issues
* Initial payment integration with checkout.js
  * purchases
  * in-process
    * process transaction
    * associate product with user
    * send user an email
* Payment Form with stripe.js
  * iframe
  * ssl
* Save transaction information with a Transaction record
  * basic record
    - amount charged
    - stripe fee
    - user_id
    - timestamps
    - stripe token
    - card info
    - stripe charge id
  * state machine with aasm
    - rationale
    - implementation
  * save transaction history with paper_trail
    - rationale
    - implementation
* [Use background workers](/background_worker)
  * rationale
  * problems they solve
  * different worker systems
    * sucker punch
    * dj
    * resque/sidekiq
* Handling callbacks
  * which callbacks are important
    * for a one-off product site, not very many
    * for subscriptions, more important
* Handling subscriptions
  * creating/managing plans
  * adding users to subscriptions
  * should you automatically cancel if they stop paying? (no)
* Email
  * receipts
  * notifications
  * card-about-to-expires
* Admin pages
  * dashboard
  * reports
  * controls
    * refunding transactions
    * cancelling/pausing subscriptions
