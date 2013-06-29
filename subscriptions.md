[koudoku]: https://github.com/andrewculver/koudoku
[stripe-rails]: https://github.com/thefrontside/stripe-rails
[stripe_event]: https://github.com/integrallis/stripe_event
[rails-stripe-membership-saas]: https://github.com/RailsApps/rails-stripe-membership-saas
[monospace-rails]: https://github.com/stripe/monospace-rails
[stripe-invoices]: https://stripe.com/docs/api#invoiceitems


# Subscriptions

## Outline

```text
* off the shelf stuff
* basic subscriptions
  * add member object with devise
  * member sign_up view gets credit card info
* the problem is that i'm going to duplicate a lot of the content from
  state and history and background workers in this chapter. Is that
  ok? not really sure. kind of a pain in the ass.
* build it first, then write about it!!!!
```

So far in the example project we've only dealt with one-off transactions, where the customer comes along and buys a product once and we basically never have to deal with them again. The majority of SaaS products aren't really like this, though. Most SaaS projects bill customers monthly for services, maybe with some kind of add-on system.

This is actually where things can get tricky for Stripe integrations. Stripe's subscription plan support is functional but basic. The general flow is:

1. Sign a user up for your system
2. Capture their credit card info using `stripe.js` or `checkout.js`
3. Create a Stripe-level customer record and attach them to a subscription plan
4. Stripe handles billing them every period with variety of callbacks that you can hook into to influence the process

The tricky part starts when people want to change their subscription plan and they have add-ons. Stripe automatically handles prorating subscription changes but since add-ons are handled using invoices you have to prorate them yourself. Let's handle the basic integration first and then we can talk about how to handle the weird case.

## Off the shelf solutions

There are a bunch of different rails engines out there that let you more or less drop a subscription system into your app.

* [Koudoku][koudoku] includes things like a pricing table, helpers for `stripe.js`, and robust plan creation. It does not have particularly good support for Stripe's webhooks.
* [Stripe::Rails][stripe-rails] has much better webhook support but doesn't help you as much with pricing tables or views
* [stripe_event][] handles *just* Stripe's webhooks, but it does a fairly good job of it.

In addition, there's a fair number of example subscription applications you can crib from:

* [monospace-rails][] is Stripe's own example subscription app
* [rails-stripe-membership-saas][] is another very good example

You should definitely check these options out. In this chapter we're not going to go over a full subscription integration, since the two example apps above are very good. Instead, we're going to hit some interesting highlights and some pain points that you might face. Just remember the advice from State and History and Background Workers. Always do your communication with Stripe in the background and set things up so you automatically get an audit trail.

## Utility-Style Billing

Handling a basic subscription is straight forward and well covered in the example apps Let's say, howeer, you're building an app where you want metered billing like a phone bill. You'd have a basic subscription for access and then monthly invoicing for anything else. Stripe has a feature they call [Invoices][stripe-invoice] that makes this easy. For example, you want to allow customers to send email to a list and base the charge it on how many emails get sent. You could do something like this:

```
class EmailSend < ActiveRecord::Base
  ...

  belongs_to :user
  after_create :add_invoice_item

  def add_invoice_item
    Stripe::InvoiceItem.create(
      customer: user.stripe_customer_id,
      amount: 10,
      currency: "usd",
      description: "email to #{address}"
    )
  end

end
```