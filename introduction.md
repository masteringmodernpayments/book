# Introduction

Thanks for purchasing *Mastering Modern Payments: Using Stripe with Rails*. In this guide we're going to walk through a complete example of integrating Stripe, a credit card payments API, with Ruby on Rails, a comprehensive modern web application stack.

## A Bit of History

Before Stripe came onto the scene, alteratives for accepting payments online were either expensive, annoying, complicated, or three. PayPal was (and still is) a large portion of the business, but the API is very old and the payment flow is not conducive to a modern application. To accept credit cards, you either you had to use PayPal or integrate at least three separate services: a merchant account, a credit card gateway, and a recurring subscription service. You had the responsibility to make sure every piece was secure, and all of the software that integrated them had to be maintained.

Stripe makes all of this irrelevant. You can create an account on Stripe's website and be making real live charges the next day with very simple, easy to use APIs and documentation

## Why this guide?

Stripe has excellent documentation. Why should you read this guide? Because the documentation does not go far enough. It often assumes that Stripe will always be available and responsive. It gives small examples that don't apply well to a production application. This guide goes farther and deeper than Stripe's documentation. It builds up a complete production-level Rails application and covers every step along the way.

In this guide we're going to cover a basic Stripe integration and then expand upon it to cover things like background workers, subscriptions, audit trails, PCI compliance, and more. When you're done with the guide you should have a good grasp on how to do a complete, robust integration.

## Who am I?

I'm Pete Keen. I've been working with the Stripe API for a little over three years now and have built many applications with it. In addition, I've worked with a wide variety of payment systems at my full time and consulting jobs and learned quite a lot about how to handle payments in general.

## Conventions

```text
Code examples are marked out like this.
```

Shorter code snippets are marked `like this`.

Links are [underlined](http://www.petekeen.net) and are all clickable from all of the electronic versions.

## Versions

This guide uses semantic versioning. The major version will change with major Rails or Stripe API changes, minor with smaller API changes, and the patch level will change when bugs or typos are fixed in the text or example code. Speaking of typos or bugs, if you spot any please email me at [bugs@petekeen.net](mailto:bugs@petekeen.com).

Versions of software used in the examples:

* Ruby 2.0.0-p0
* Rails 4.0.2
* Stripe Ruby API 1.8.3
* Devise 3.0.0.rc
* Paper Trail rails4 branch
* PostgreSQL 9.2
