# Subscriptions

So far in the example project we've only dealt with one-off transactions, where the customer comes along and buys a product once and we basically never have to deal with them again. The majority of SaaS products aren't really like this, though. Most SaaS projects bill customers monthly for services, maybe with some kind of addon system.

This is actually where things can get tricky for Stripe integrations. Stripe's subscription plan support is functional but basic. The basic flow is:

1. Sign a user up for your system
2. Capture their credit card info using `stripe.js` or `checkout.js`
3. Create a Stripe-level customer record and attach them to a subscription plan
4. Stripe handles billing them every period with variety of callbacks that you can hook into to influence the process

## Basic Subscription Integration

## Handling Upgrades and Downgrades

## Handling Addons
