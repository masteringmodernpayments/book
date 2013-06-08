[bootstrap]: http://twitter.github.io/bootstrap

# Custom Payment Forms

Until now we've been using Stripe's excellent `checkout.js` that provides a popup iframe to collect credit card information, post it to Stripe and turn it into a `stripeToken` and then finally post our form. There's something conspicuously absent from all of this, however. Remember how Sale has an email attribute? We're not populating that right now because `checkout.js` doesn't easily let us add our own fields. For that we'll need to create our own form. Stripe still makes this easy, though, with `stripe.js`.

## Inline Form

Here's the form we'll be using:

```erb
<%= form_tag buy_path(permalink: @product.permalink), :class => 'form-horizontal', :id => 'payment-form' do %>
  <span class="payment-errors"></span>
  <div class="control-group">
    <label class="control-label" for="email">Email</label>
    <div class="controls">
      <input type="email" name="email" id="email" placeholder="Email"/>
    </div>
  </div>
  <div class="control-group">
    <label class="control-label" for="number">Card Number</label>
    <div class="controls">
      <input type="text" size="20" data-stripe="number" id="number" placeholder="**** **** **** ****"/>
    </div>
  </div>

  <div class="control-group">
    <label class="control-label" for="cvc">CVC</label>
    <div class="controls">
      <input type="text" size="3" data-stripe="cvc" id="cvc" placeholder="***"/>
    </label>
  </div>

  <div class="form-row">
    <label class="control-label">Expiration (MM/YYYY)</label>
    <div class="controls">
      <input type="text" size="2" data-stripe="exp-month" placeholder="MM"/>
      <span> / </span>
      <input type="text" size="4" data-stripe="exp-year" placeholder="YYYY"/>
    </div>
  </div>

  <div class="form-row">
    <div class="controls">
      <button type="submit">Pay</button>
    </div>
  </div>
<% end %>
```

There's a few interesting things going on here. First, notice the almost-excessive amount of markup. I'm using [Twitter Bootstrap][bootstrap] style form markup for this, which gives nice looking styling by default. Second, take a look at the inputs. Only one of them, `email`, actually has a `name` attribute. The rest have `data-stripe` attributes. Browsers will only send inputs that have a `name` to the server, the rest get dropped on the floor. In this case, the inputs with `data-stripe` attributes will get picked up by `stripe.js` automatically and fed to Stripe's servers to be turned into a token.

To do that we need to actually send the form to Stripe. First include `stripe.js` in the page. Stripe recommends you do this in the header for compatibility with older browsers, but we're just going to stick it in the body for now. Put this at the bottom of the page:

```html
<script type="text/javascript" src="https://js.stripe.com/v2/"></script>
```


