[bootstrap]: http://twitter.github.io/bootstrap
[tutorial]: https://stripe.com/docs/tutorials/forms

# Custom Payment Form

Until now we've been using Stripe's excellent `checkout.js` that provides a popup iframe to collect credit card information, post it to Stripe and turn it into a `stripeToken` and then finally post our form. There's something conspicuously absent from all of this, however. Remember how Sale has an email attribute? We're not populating that right now because `checkout.js` doesn't easily let us add our own fields. For that we'll need to create our own form. Stripe still makes this easy, though, with `stripe.js`. The first half of this chapter is adapted from Stripe's [custom form tutorial][tutorial].

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
      <button type="submit" class="btn btn-primary">Pay</button>
    </div>
  </div>
<% end %>
```

There's a few interesting things going on here. First, notice the almost-excessive amount of markup. I'm using [Twitter Bootstrap][bootstrap] form markup for this, which gives nice looking styling by default.

Second, take a look at the inputs. Only one of them, `email`, actually has a `name` attribute. The rest have `data-stripe` attributes. Browsers will only send inputs that have a `name` to the server, the rest get dropped on the floor. In this case, the inputs with `data-stripe` attributes will get picked up by `stripe.js` automatically and fed to Stripe's servers to be turned into a token.

To do that we need to actually send the form to Stripe. First include `stripe.js` in the page. Stripe recommends you do this in the header for compatibility with older browsers, but we're just going to stick it in the body for now. Put this at the bottom of the page:

```html
<script type="text/javascript" src="https://js.stripe.com/v2/"></script>
```

Next, Stripe needs our publishable key. Remember that we have that in the Rails config due to the initializer we [set up before](/initial_app). To set it, call `Stripe.setPublishableKey()` like this:

```erb
<script type="text/javascript">
$(function({
  Stripe.setPublishableKey('<%= Rails.configuration.stripe[:publishable_key] %>');
});
</script>
```

To intercept the form submission process, tack on a `submit` handler using jQuery:

```javascript
$('#payment-form').submit(function(event) {
  var form = $(this);
  form.find('button').prop('disabled', true);
  Stripe.createToken(form, stripeResponseHandler);
  return false;
});
```

When the customer clicks the "Pay" button we disable the button so they can't click it again, then call `Stripe.createToken`, passing in the form and a callback function. Stripe's javascript will submit all of the inputs with a  `data-stripe` attribute to their server, create a token, and call the callback function with a status and response. The implmentation of `stripeResponseHandler` is pretty straightforward:

```javascript
function stripeResponseHandler(status, response) {
  var form = $('#payment-form');
  if (response.error) {
    form.find('.payment-errors').text(response.error.message);
    form.find('button').prop('disabled', false);
  } else {
    var token = response.id;
    form.append($('<input type="hidden" name="stripeToken">').val(token));
    form.get(0).submit();
  }
}
```

If the response has an error, display the error and re-enable the "Pay" button. Otherwise, append a hidden input to the form and resubmit using the DOM method instead of the jQuery method so we don't get stuck in an infinite loop.

## Embedding the Form

Custom forms are all well and good, but wouldn't it be cool if we could embed it in another page just like Stripe's Checkout? Let's give it a shot. Create a file `public/example.html` and put this in it:

```html
<html>
  <head>
    <link href="//netdna.bootstrapcdn.com/twitter-bootstrap/2.3.2/css/bootstrap-combined.min.css" rel="stylesheet">
  </head>
  <body>
    <h1>Example Iframe</h1>
    <button class="btn btn-primary" id="openBtn">Buy</button>
    <div id="paymentModal" class="modal hide fade" role="dialog">
      <div class="modal-body">
        <iframe src="" style="zoom:0.6" width="99.6%" height="550" frameborder="0"></iframe>
      </div>
    </div>
    <script src="//ajax.googleapis.com/ajax/libs/jquery/2.0.2/jquery.min.js"></script>
    <script src="//netdna.bootstrapcdn.com/twitter-bootstrap/2.3.2/js/bootstrap.min.js"></script>
    <script type="text/javascript">
      var frameSrc = "/buy/design-for-failure"; // You'll want to customize this.
      $("#openBtn").click(function() {
        $("#paymentModal").on("show", function() {
          $('iframe').attr('src', frameSrc);
        });
        $("#paymentModal").modal({show: true});
      });
    </script>
  </body>
</html>
```

This page loads jQuery and Twitter Bootstrap from public CDNs and then uses them to create a Bootstrap Modal containing an `iframe`. Initially this iframe's `src` attribute is set to nothing. This is to prevent the iframe from loading on page load which could cause a lot of unnecessary traffic on the server running the sales application. When the customer clicks the button we set up the `src` attribute of the iframe and then show the modal.

This is pretty cool but also problematic. The iframe just loads the normal `/buy` action which contains the whole product description. Second, and more importantly, after the customer buys the thing they expect to be able to click on the download link and save the product, but that won't happen because we haven't set the `X-Frame-Options` header to allow the iframe to do anything. Let's fix the first problem. Move the form into a new partial named `_form.html.erb` and then call it like this in `transactions/new.html.erb`:

```erb
<%= render :partial => 'form' %>
```

Then, create a new action named `iframe`:

```ruby
# in config/routes.rb

match '/iframe/:permalink' => 'transactions#iframe', via: :get, as: :buy_iframe
```

```ruby
# in app/controllers/transactions_controller.rb

def iframe
  @product = Product.where(permalink: params[:permalink]).first
  raise ActionController::RoutingError.new("Not found") unless @product
end
```

In `app/views/transactions/iframe.html.rb`:

```erb
<h1><%= @product.name %></h1>

<p>Price: <%= formatted_price(@product.price) %></p>

<%= render :partial => 'form' %>
```

Now, change `frameSrc` to point at `/iframe/design-for-failure` and reload the page.

We can fix the other problem, with the `X-Frame-Options` header, simply by changing the language to say "Make sure to right-click and select Save As" indead of just telling the customer to click the link. In a later chapter I'll talk about emailing and we'll be changing this some more.
