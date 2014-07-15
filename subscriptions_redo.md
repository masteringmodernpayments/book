# Subscriptions

* topic
* list

---

So far in this book we've talked about how to sell products once. A customer selects a product, puts their information in, and hits the "buy now" button, and that's end of our interaction with them.

The majority of SaaS businesses don't operate that way. Most of them will want their customers to pay on a regular schedule. Stripe has built-in support for these kinds of subscription payments that is easy to work with and convenient to set up. In this chapter, we're going to go through a basic integration, following the same priciples that we've laid out for the one-time product sales. Then, we'll explore some more advanced topics, including how to effectively use the subscription webhook events, in-depth coverage of Stripe's plans, and options for reporting.

## Basic Integration

* models
  - plan
  - subscription
  - additions to user
* basic pricing table
* collecting card information
* creating a customer with a subscription
* adding more than one subscription
* user roles (authority gem)

## Testing

* mocking with stripe mock

## Webhooks and Emails

* interesting events
* testing
* dunning emails

## Plans In-depth

* how to deal with multiple plans (naming scheme)
* upgrading, downgrading, and prorating
* free trials, both with and without card
* usage billing (utility style)

## Reporting

* keeping your db in sync with stripe