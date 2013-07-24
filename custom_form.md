[custom-form-bootstrap]: http://twitter.github.io/bootstrap
[custom-form-tutorial]: https://stripe.com/docs/tutorials/forms

# Custom Payment Forms

Until now we've been using Stripe's excellent `checkout.js` that provides a popup iframe to collect credit card information, post it to Stripe and turn it into a `stripeToken` and then finally post our form. There's something conspicuously absent from all of this, however. Remember how Sale has an email attribute? We're not populating that right now because `checkout.js` doesn't let us add our own fields. For that we'll need to create our own form. Stripe makes this easy though, with `stripe.js`. The first half of this chapter is adapted from Stripe's [custom form tutorial][custom-form-tutorial].

Here's the form we'll be using:

![Custom credit card form](card_form.png)

And here's the code:

```rhtml
<div class="well" style="margin-left: 0px; position: relative; min-width: 650px; min-height: 180px; max-height: 180px">
  <%= form_tag buy_path(permalink: permalink), :class => '', :id => 'payment-form' do %>
    <div class="row">
    </div>
    <div class="row">
      <div style="position: absolute; left: 20px">
        <label class="control-label" for="email">Email</label>
        <input type="email" name="email" id="email" placeholder="you@example.com" style="width: 25em"/>
      </div>
      <div style="position: absolute; left: 400px">
        <label class="control-label" for="number">Card Number</label>
        <input type="text" size="20" data-stripe="number" id="number" placeholder="**** **** **** ****" pattern="[\d ]*" style="width: 18em"/>
      </div>
    </div>
    <div class="row" style="margin-top: 65px">
      <div style="position: absolute; left: 20px">
        <label class="control-label" for="cvc">CVC</label>
        <input type="text" style="width: 3em" size="3" data-stripe="cvc" id="cvc" placeholder="***" pattern="\d*"/>
        <img id="card-image" src="/img/credit.png" style="height: 30px; padding-left: 10px; margin-top: -10px">
      </div>
      <div style="position: absolute; left: 150px">
        <label class="control-label">Exp (MM/YYYY)</label>
        <input style="width: 2em" type="text" size="2" id="exp-month" data-stripe="exp-month" placeholder="MM" pattern="\d*"/>
        <span> / </span>
        <input style="width: 3em" type="text" size="4" id="exp-year" data-stripe="exp-year" placeholder="YYYY" pattern="\d*"/>
      </div>
    </div>
    <div class="row" style="margin-top: 70px">
      <div class="price" style="position: absolute; left: 20px;"><%= price %></div>
      <div style="position: absolute; left: 400px">
        <button type="submit" class="btn btn-primary btn-large">Buy Now</button>
        <img style="display: none;" src="/img/well_spinner.gif" id="spinner">
      </div>
    </div>
  <% end %>
</div>
```

There's a few interesting things going on here. First, notice the almost-excessive amount of markup. We're using [Twitter Bootstrap][custom-form-bootstrap] form markup for this, which gives nice looking styling for the form elements but requires a bunch of layout markup.

Second, take a look at the inputs. Only one of them, `email`, actually has a `name` attribute. The rest have `data-stripe` attributes. Browsers will only send inputs that have a `name` to the server, the rest get dropped on the floor. In this case, the inputs with `data-stripe` attributes will get picked up by `stripe.js` automatically and fed to Stripe's servers to be turned into a token.

To do that we need to actually send the form to Stripe. First include `stripe.js` in the page. Stripe recommends you do this in the header for compatibility with older browsers, but we're just going to stick it in the body for now. Put this at the bottom of the page:

```html
<script type="text/javascript" src="https://js.stripe.com/v2/"></script>
```

Next, Stripe needs our publishable key. Remember that we have that in the Rails config due to the initializer we set up in the initial application. To set it call `Stripe.setPublishableKey()` like this:

```rhtml
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

When the customer clicks the "Pay" button we disable it so they can't click again, then call `Stripe.createToken`, passing in the form and a callback function. Stripe's JavaScript will submit all of the inputs with a  `data-stripe` attribute to their server, create a token, and call the callback function with a status and response. The implementation of `stripeResponseHandler` is pretty straightforward:

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
    <h1>Example iframe</h1>
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

The iframe just loads the normal `/buy` action which contains the whole product description. More importantly, after the customer buys the thing they expect to be able to click on the download link and save the product, but that won't happen because we haven't set the `X-Frame-Options` header to allow the iframe to do anything. Let's fix the first problem. Move the form into a new partial named `_form.html.erb` and then call it like this in `transactions/new.html.erb`:

```rhtml
<%= render :partial => 'form' %>
```

Then, create a new action named `iframe`, first in `config/routes.rb`:

```ruby
match '/iframe/:permalink' => 'transactions#iframe', via: :get, as: :buy_iframe
```

In `app/controllers/transactions_controller.rb`:

```ruby
def iframe
  @product = Product.find_by!(permalink: params[:permalink])
end
```

In `app/views/transactions/iframe.html.rb`:

```rhtml
<h1><%= @product.name %></h1>

<p>Price: <%= formatted_price(@product.price) %></p>

<%= render :partial => 'form' %>
```

Now, change `frameSrc` to point at `/iframe/design-for-failure` and reload the page.

We can fix the other problem, with the `X-Frame-Options` header, simply by changing the language to say "Make sure to right-click and select Save As" indead of just telling the customer to click the link. In a later chapter I'll talk about emailing and we'll be changing this some more.

## Next

We have an application where you can upload products and sell them to customers who can then download them. In this chapter we created a custom payment form. In the next chapter we're going to talk about keeping an audit trail using state machines and a gem named Papertrail.
