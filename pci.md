# PCI Compliance

[pci]: https://www.pcisecuritystandards.org
[stripe_pci]: https://stripe.com/help/security
[rsa]: http://en.wikipedia.org/wiki/RSA_(algorithm)
[namecheap_ssl]: http://www.namecheap.com/ssl-certificates.aspx
[heroku_ssl]: https://devcenter.heroku.com/articles/ssl-endpoint

One of the biggest reasons to choose Stripe over other ways of processing credit cards is that they minimize your exposure to *PCI compliance*. PCI stands for "[Payment Card Industry][pci]", if you were wondering.

Note: I'm not an expert in PCI compliance and this chapter shouldn't be interpreted as legal advice about it. Rather, this is background information and advice on how to implement Stripe's guidelines. If you have questions, please ask Stripe.

Back in the early 2000s the credit card industry got together and decided on a whole bunch of interrelated standards for how to secure a payment system such that personally identifiable information, especially credit card numbers, is unlikely to be leaked to the outside world. For example, before the era of PCI compliance it was common for your unencrypted credit card number to be tacked onto your user record in an application database. Also, it was typical for sites to use plain HTTP for payment forms instead of HTTPS.

Now, though, both of those practices along with a host of others would get your merchant account cancelled. Being PCI compliant means that you adhere to all of the practices that apply to the way you process credit cards. Stripe is certified Service Provider Level 1, which means they have to have store credit card information encrypted in separate machines, possibly in separate data centers, than all of the rest of their infrastructure. It also means that nobody internal to Stripe can access unencrypted credit card numbers. Their software makes charges based on your API calls by sending information to an exclusive set of providers, entirely hidden from employees.

## Stripe and PCI

The real revolutionary part of how Stripe works is in how they [reduce your compliance scope][stripe_pci] as a merchant. Before Stripe, a typical online merchant would have a normal HTML form on their website where customers would put in their credit card information. This form would post to the merchant's server, where they would take the credit card info and pass it along to their *gateway service*, which would then talk to all of the various banks and things and then eventually deposit the money into their *merchant account*. This means, among other things, that each merchant would have to become PCI certified, even if they weren't storing the credit card info anywhere in their system. Theoretically, an attacker could stick some code into a merchant's payment processing system and divert credit card numbers. Or, if the merchant's site wasn't using HTTPS they could perform a man-in-the-middle attack and capture credit card info that way.

Stripe, with `stripe.js`, makes all of this irrelevant. When you create a form using `stripe.js` or `checkout.js` loaded from Stripe's servers, none of the customer's credit card info is sent through your servers. The javascript that gets injected into your form instead sends that info to Stripe's servers over HTTPS, where they turn it into a single-use *token*. Your server can then use that token to refer to a customer's credit card without having seen it at all.

The only thing you as a merchant have to do to be PCI compliant in this situation is to make sure you're serving up your payment-related pages over HTTPS. As long as you're loading `stripe.js` from Stripe via HTTPS into a secure webpage which POSTs to a secure endpoint, and you make sure not to put `name`s on any of the credit-card-related fields in the form (only fields with `name`s get POSTed), you don't have to worry about PCI compliance at all.

## Implementing HTTPS with Rails

Rails after v3.1 makes forcing visitors to HTTPS incredibly easy. In `config/environments/production.rb`:

```ruby
config.force_ssl = true
```

This will redirect all non-https requests to your website to the secure endpoint automatically on production. For this example it's all we need to do because Heroku provides what's called a "wildcard ssl certificate" for all apps accessed at `herokuapp.com`. However, if you're using your own URL you'll need to get your own certificate (generally around $10 per year) and install it with Heroku, which will run $20 per month. These costs vary, of course, if you're using a different hosting provider. Most Amazon-based cloud providers will charge $20 because that's how much an Elastic Load Balancer costs.

## Buying a Certificate

There are many different places where you can buy a certificate. I've had good luck buying them through my registrar [Namecheap.com][namecheap]. The steps are:

* Generate a private key
* Using your private key, generate a Certificate Signing Request
* Send the CSR to Namecheap
* Receive your shiny new certificate
* Remove the passphrase from your certificate so that the webserver can use it.

First make sure you have `openssl` installed on your machine. It comes installed by default on Mac OS X but on Linux you may have to install it from your package manager.

### Generate a Private Key

```bash
$ openssl genrsa -out example.com.key 2048
```

This generates a 2048 bit [RSA key][rsa] and stores it in `example.com.key`.

### Generate a Certificate Signing Request

```bash
$ openssl req -new -key example.com.key -out example.com.csr
```

OpenSSL will ask you a bunch of questions now. Fill them in like the prompts, but when you get to the `Common Name` question, use the exact name of web server. Note that this really does have to be an exact match, so if you want to secure, say, `www.example.com`. that's what you should use. Putting just `example.com` won't work. For a wildcard certificate you'd put `*.example.com`, which would let you secure `foo.example.com` and `bar.example.com`, but those cost quite a bit more than individual certificates.

Also, make sure to leave extra attributes including the challenge password blank.

### Validate your new CSR

```bash
$ openssl req -noout -text -in example.com.csr
```

This will print out a bunch of information about your certificate. You can ignore almost all of it, but pay attention to the line `CN=example.com`. This should match what you put in for your server name in the `Common Name` field.

### Buy the actual certificate

Head on over to [Namecheap's SSL page][namecheap_ssl]. Here you're presented with a bunch of different options presented in what they feel is least-secure to most-secure list. I generally buy the cheapest option because they're all pretty much the same in the $10 range. If you want, you can get EV1 certification which will give you the green bar in Safari and Firefox. You'll have to do some more paperwork to get it, though. For now, let's just get the cheapest Comodo certificate.

Go through checkout and pay and you'll get sent to a page where you can pick your server type and paste your CSR. For Heroku you should choose the "Other" option in the server dropdown. Open your CSR up and paste the entire contents into the text box, then hit Next.

Namecheap will give you a list of email addresses to choose from. This is where it's going to send the verification email that contains a link you have to click to proceed through the process. If you don't already have one of these email aliases set up, you should do so now before picking one and clicking Next.

You'll now be prompted to enter your administrative contact info, which it helpfully copied from your domain registration if you registered through Namecheap. Fill this stuff out, then hit Next.

You'll get taken to a web page with a handy dandy flow chart, and within a few mintues you'll get an email. Click the link in the email, copy and paste the verification code, and hit the "Next" button. You'll get another email, this one with your new certificate attached.

### Installing the certificate at Heroku

At this point, you'll need to attach the SSL certificate to your application. With Heroku, [this is easy][heroku_ssl].

```bash
$ heroku addons:add ssl:endpoint
$ heroku certs:add www.example.com.crt bundle.pem example.com.key
```

To see if the certificate installed properly:

```bash
$ heroku certs
```

Now just configure `www.example.com` as a CNAME pointing at the `herokussl.com` endpoint printed from `heroku certs` and test it out:

```bash
$ curl -kvI https://www.example.com
```

This should print out a bunch of stuff about SSL and the headers from your application.

