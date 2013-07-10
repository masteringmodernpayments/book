# Introduction

Thanks for purchasing *Mastering Modern Payments*. In this guide we're going to talk about integrating the Stripe payment processing system with Rails, a comprehensive modern web application stack. If you don't use Rails you'll have to translate the examples to your language and framework of choice, but the broad concepts should all transfer pretty well.

Stripe has revolutionized the payment landscape for Software as a Service applications. Before Stripe you had to deal with multiple parties, multiple moving pieces, and integrate everything yourself. Now, all you have to do is make some very simple API calls. You don't even have to create an account, since the documentation site creates one for you on the fly so every example is directly usable.

## Why this guide?

Stripe has excellent documentation. Why should you read this guide? Because the documentation does not go far enough. It assumes that Stripe will always be available and responsive. It gives small examples that don't apply well to a production application. This guide goes farther and deeper than the short examples in Stripe's documentation and fully fleshes out production-level code.

In this guide we're going to cover a basic Stripe integration and then expand upon it to cover things like background workers, subscriptions, audit trails, and more. When you're done with the guide you should have a good grasp on how to do a complete, robust integration.

## Who am I?

I'm Pete Keen. I've been working with the Stripe API for a little over two years now and have built six applications that run payments through it. In addition, I've worked with a wide variety of payment systems at my day job. I've seen learned quite a lot about how to handle payments in general and I've tried to condense it down into something manageable in this guide.

## Versions

This guide uses semantic versioning. The current version is **0.1.0**. The major version will change with major Rails or Stripe API changes, minor with smaller API changes, and the patch level will change when bugs or typos are fixed in the text or example code. Speaking of typos or bugs, if you spot any please email me at [bugs@petekeen.net](mailto:bugs@petekeen.com).

Versions of software used in examples:

* Ruby 2.0.0-p0
* Rails 4.0.0
* Stripe Ruby API 1.8.3
* Devise 3.0.0.rc
* Paper Trail rails4 branch

## Conventions

```text
Code examples are marked out like this.
```

Shorter code snippets are marked `like this`.

Links are [underlined](http://www.petekeen.net) and are all clickable from all of the electronic versions.
