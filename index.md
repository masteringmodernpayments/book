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
  * save transaction history with paper_trail
* Handlging callbacks
* Use background workers
  * rationale
  * problems they solve
  * different worker systems
    * sucker punch
    * dj
    * resque/sidekiq
* Handling subscriptions
* Email
  * receipts
  * notifications
  * card-about-to-expires
* Admin pages
  * dashboard
  * reports



