---
discussion_issue: 2
title: Introduction
preview: true
bullets:
  - Learn what makes Stripe great
  - Read about this book
  - Learn how the book is organized
---

Before Stripe came onto the scene, alteratives for accepting payments online were either expensive, annoying, complicated, or all three. PayPal had (and still has) a large portion of the business, but the API is very old and the payment flow is not conducive to a modern application. To accept credit cards, you either you had to use PayPal or integrate at least three separate services: a merchant account, a credit card gateway, and a recurring subscription service. You had the responsibility to make sure every piece was secure, and all of the software that integrated them had to be maintained.

Stripe makes all of this irrelevant. You can create an account on Stripe's website and be making real live charges the next day with simple, easy to use APIs and documentation. The power of this is huge: you can go from idea to accepting payments in very little time, often less than a day.

## Why this guide?

If Stripe is so easy to use, why read a whole book about it? There's a few reasons. Stripe's documentation often does not go far enough. It assumes that Stripe will always be availble and responsive. It also only gives small or limited examples that don't directly apply to production applications.

This guide goes farther and deeper than Stripe's documentation. It builds up a complete production-level Rails application and covers every step along the way.

In this guide we're going to cover a basic Stripe integration and then expand upon it to cover things like background workers, subscriptions, marketplaces, audit trails, PCI compliance, and more. When you're done with the guide you should have a good grasp on how to build a complete, robust Stripe integration.

## How does the guide work?

This guide builds an application lovingly named Sully after the big blue monster in the Pixar movie Monsters, Inc. Sully's job is to sell downloadable products. By the end of the book it will be a full marketplace where sellers can upload one-off and subscription content.

Each chapter has a GitHub discussion thread associated with it that you can get to by clicking on the Discuss button in the upper lefthand corner. Here, you can ask questions and give help to your fellow readers.

## Who am I?

My name is Pete Keen. I've been working with the Stripe API for a little over three years now and have built many applications with it. In addition, I've worked with a wide variety of other payment systems at my full time and consulting jobs and learned quite a lot about how to handle payments in general.

## Conventions

```text
Code examples are marked out like this.
```

Shorter code snippets are marked `like this`.

Links are [underlined](http://www.petekeen.net) and are all clickable from all of the electronic versions.

## Versions

Versions of software used in the examples:

* Ruby 2.0.0-p0
* Rails 4.0.2
* Stripe Ruby API 1.15.0
* Devise 3.3.0
* Paper Trail 3.0
* PostgreSQL 9.2

See the [Changelog](/changelog) for details about changes to the guide itself.
