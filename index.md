# Mastering Modern Payments
## Using Stripe with Rails

* Introduction
* Initial app description
  * products
  * users/admins
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
    * amount charged
    * user_id
    * timestamps
    * stripe token
    * card info
    * stripe charge id
  * state machine with aasm
    * rationale
    * implementation
  * save transaction history with paper_trail
    * rationale
    * implementation
* Use background workers
  * rationale
  * problems they solve
  * different worker systems
    * sucker punch
    * dj
    * resque/sidekiq
* Handlging callbacks
  * which callbacks are important
    * for a one-off product site, not very many
    * for subscriptions, more important
* Handling subscriptions
* Email
  * receipts
  * notifications
  * card-about-to-expires
* Admin pages
  * dashboard
  * reports



