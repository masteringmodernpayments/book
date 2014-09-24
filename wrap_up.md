---
discussion_issue: 11
---

# Additional Resources

* More links to docs, examples, and libraries

---

Hopefully this guide has given you a good overview of working with Stripe with Rails and the tips and hints I've given have been helpful. What follows is a list of links to additional resources that I've found very helpful to my Stripe implementations.

## Documentation

* [Stripe's documentation](https://stripe.com/docs) is truly excellent. If some question isn't answered in this book that should be the first place you look.
* [Stripe Ruby API Docs](https://stripe.com/docs/api/ruby): The Ruby API has it's own documentation mini site
* [Stripe Ruby API code](https://github.com/stripe/stripe-ruby): The ruby API is open source and is a pretty good read. If you're looking to build a comprehensive HTTP API in Ruby you should definitely model it on this.

## Examples

* [Stripe's GitHub Projects](https://github.com/stripe) contain lots of gems, including all of their language SDKs
* [Rails Stripe Membership SaaS](http://railsapps.github.io/rails-stripe-membership-saas/) is a comprehensive example of a Stripe membership integration.
* [RailsApps](http://railsapps.github.io) is great collection of example Rails apps in general.
* [Working with Stripe Payouts](http://blog.chriswinn.com/working-with-stripe-payouts) is a short article about integrating Stripe Payouts into your rails app
* [Monospace Rails](https://github.com/stripe/monospace-rails), Stripe's official subscription example

## Libraries

* [Koudoku](https://github.com/andrewculver/koudoku), a Rails engine for subscription billing with Stripe
* [StripeEvent](https://github.com/integrallis/stripe_event), a Rails engine for Stripe event handling
* [StripeMock](https://github.com/rebelidealist/stripe-ruby-mock), a library for mocking and testing Stripe webhooks and API integrations
* [StripeTester](https://github.com/buttercloud/stripe_tester), another library for testing Stripe webhooks
* [Devise](https://github.com/plataformatec/devise), a Rails authentication library
* [CanCan](https://github.com/ryanb/cancan), a Rails authorization library
* [jQuery Payment](https://github.com/stripe/jquery.payment) is a very useful set of jQuery functions for working with payment fields
* [Stripe Auto Paginate](https://github.com/vandrijevik/stripe_auto_paginate) sets up automatic pagination for Stripe's API responses

## Additional Reading

* [The Tangled Web](http://lcamtuf.coredump.cx/tangled/) is a guide to web security and how crazy the internet really is. Not directly applicable to a Stripe/Rails integration but it is a great read and is full of useful tips and explanations. Highly recommended.
* [Developer's Guide to PCI Compliant Web Applications](http://kencochrane.net/blog/2012/01/developers-guide-to-pci-compliant-web-applications/) goes into great depth about how to write a PCI compliant web application, and how Stripe makes it easier.
