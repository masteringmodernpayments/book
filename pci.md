# Security and PCI Compliance

[pci-pci]: https://www.pcisecuritystandards.org
[pci-stripe_pci]: https://stripe.com/help/security
[pci-rsa]: http://en.wikipedia.org/wiki/RSA_(algorithm)
[pci-namecheap_ssl]: http://www.namecheap.com/ssl-certificates.aspx
[pci-heroku_ssl]: https://devcenter.heroku.com/articles/ssl-endpoint
[pci-rbp]: http://rails-bestpractices.com
[pci-brakeman]: http://brakemanscanner.org
[pci-cochrane]: http://kencochrane.net/blog/2012/01/developers-guide-to-pci-compliant-web-applications/

<em>Note: I'm not an expert in PCI compliance and this chapter shouldn't be interpreted as legal advice. Rather, this is background information and advice on how to implement Stripe's guidelines. If you have questions, please ask Stripe or your nearest local PCI consultant.<em>

In 2004 all of the various card processing companies including Mastercard, Visa, and Discover, started formulating security standards efforts with the aim of reducing the ongoing rash of credit card fraud. Visa dropped their own effort in 2005 and joined up with Mastercard, shortly followed by the rest of the industry. In 2006 version 1 of the [Payment Card Industry Data Security Standards][pci-pci] was officially published which formalized and codified a bunch of common-sense security requirements for processing credit cards. In their merchant agreements every processor specifies that you have to comply with PCI or your account will be dropped and you'll get audited, which is rather undesirable.

## Developer's Guide

One of the best resources that I've found that talks about all of these requirements is Ken Cochrane's [Developers Guide to PCI Compliant Web Applications][pci-cochrane]. He goes into quite a bit of depth on the various rules, regulations, and mitigation strategies that are out there. Most of the advice is platform-agnostic but some is Django-specific. All of it is great.

## Stripe and PCI

The real revolutionary part of how Stripe works is in how they [reduce your compliance scope][pci-stripe_pci] as a merchant. Before Stripe, a typical online merchant would have a normal HTML form on their website where customers would put in their credit card information. This form would post to the merchant's server, where they would take the credit card info and pass it along to their *gateway service*, which would then talk to all of the various banks and things and then eventually deposit the money into their *merchant account*.  Theoretically an attacker could stick some code into a merchant's payment processing system and divert credit card numbers. Or, if the merchant's site wasn't using HTTPS they could perform a man-in-the-middle attack and capture credit card information as it travels over the wire. This means that each and every merchant would have to become PCI certified, even if they weren't storing the credit card info anywhere in their system.

Stripe makes all of this irrelevant with their tokenization process. When you create a form using `stripe.js` or `checkout.js` loaded from Stripe's servers none of your customer's credit card info is sent through your servers. Instead, the javascript your form calls sends that info to Stripe's servers over HTTPS, where they turn it into a single-use *token* which you post to your app. Your server can then use that token to refer to a customer's credit card without ever having seen it.

The only thing you as a merchant have to do to be PCI compliant according to Stripe is to make sure you're serving up your payment-related pages over HTTPS and ensure they use `stripe.js` or `checkout.js`. We've already talked about `checkout.js` and we'll cover `stripe.js` in the chapter on Custom Forms. Let's talk about setting up HTTPS.

## Implementing HTTPS with Rails

Rails after v3.1 makes forcing visitors to HTTPS incredibly easy. In `config/environments/production.rb`:

```ruby
config.force_ssl = true
```

This will redirect all non-https requests to https automatically on production. In addition it will set the `Strict-Transport-Security` header to ensure future requests get forced to SSL without asking first, and it ensures that all cookies get the `secure` flag. For this example it's all we need to do because Heroku provides what's called a "wildcard ssl certificate" for all apps accessed at `herokuapp.com`. If you're using your own URL you'll need to get your own certificate (generally around $10 per year) and install it with Heroku which will cost $20 per month. These costs vary if you're using a different hosting provider but most Amazon-based cloud providers will charge $20 because that's how much an Elastic Load Balancer is, which is where the SSL termination actually happens.

## Buying a Certificate

There are many different places where you can buy a certificate. I've had good luck buying them through my registrar [Namecheap.com][pci-namecheap_ssl]. The steps are:

* Generate a private key
* Using your private key, generate a Certificate Signing Request
* Send the CSR to Namecheap
* Receive your shiny new certificate

First make sure you have `openssl` installed on your machine. It comes installed by default on Mac OS X but on Linux you may have to install it from your package manager.

### Generate a Private Key

```bash
$ openssl genrsa -out example.com.key 2048
```

This generates a 2048 bit [RSA key][pci-rsa] and stores it in `example.com.key`.

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

Head on over to [Namecheap's SSL page][pci-namecheap_ssl]. Here you're presented with a bunch of different options presented in what they feel is least-secure to most-secure list. I generally buy the cheapest option because they're all pretty much the same in the $10 range. If you want, you can get EV1 certification which will give you the green bar in Safari and Firefox. You'll have to do some more paperwork to get it, though. For now, let's just get the cheapest Comodo certificate.

Go through checkout and pay and you'll get sent to a page where you can pick your server type and paste your CSR. For Heroku you should choose the "Other" option in the server dropdown. Open your CSR up and paste the entire contents into the text box, then hit Next.

Namecheap will give you a list of email addresses to choose from. This is where it's going to send the verification email that contains a link you have to click to proceed through the process. If you don't already have one of these email aliases set up, you should do so now before picking one and clicking Next.

You'll now be prompted to enter your administrative contact info, which it helpfully copied from your domain registration if you registered through Namecheap. Fill this stuff out, then hit Next.

You'll get taken to a web page with a handy dandy flow chart, and within a few mintues you'll get an email. Click the link in the email, copy and paste the verification code, and hit the "Next" button. You'll get another email, this one with your new certificate attached.

### Installing the certificate at Heroku

At this point, you'll need to attach the SSL certificate to your application. With Heroku, [this is easy][pci-heroku_ssl].

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

## Additional Security Best Practices

There are a few other things you can do to help ensure that your Rails application is secure, above and beyond requiring HTTPS. Adhering to Rails best practices and making sure you don't accidentally introduce known attack vectors into your code are two of the best things you can do to make sure attackers won't be successful.

### Rails Best Practices

[Rails Best Practices][pci-rbp] is a website where people can submit and upvote various practices that help to keep your app safe and secure, and help structure your code in a maintainable way. Conveniently, Rails Best Practices also publishes a gem that automatically checks your app against more than fourty of the most common best practices. To install it, add it to the `Gemfile`:

```ruby
gem 'rails_best_practices'
```

I also recommend adding a rake task to simplfy running it. In `lib/tasks/security.rake`:

```ruby
task :rails_best_practices do
  path = File.expand_path("../../../", __FILE__)
  sh "rails_best_practices #{path}"
end
```
 
The Rails scaffolding tends to produce code that doesn't adhere to these practices. Most notably it uses instance variables inside partials and it generates verbose render statements inside forms. The fix is pretty easy. Change this:

```erb
<%= form_for @object do |f| %>
  <%= f.text_input :attribute %>
<% end %>
```

```erb
<%= render partial: 'form' %>
```

To this:

```erb
<%= form_for object do |f| %>
  <%= f.text_input :attribute %>
<% end %>
```

```erb
<%= render 'form', object: @object %>
```

In more recent versions of Rails `render` is a lot smarter than it used to be. It knows based on context what we mean by the second argument. We also don't have to specify the `locals:` key anymore, it's just implied that the second argument is the locals hash when rendering a partial.

### Brakeman

[Brakeman][pci-brakeman] is a security static analysis scanner for Rails applications. It goes through your code looking for known security vulnerabilities and suggests fixes. The default Rails application, in fact, ships with one of these vulnerabilities. Rails generates a "secret token" that it uses to encrypt session information and sign cookies so users can't modify it. By default, it sticks this token into `config/initializers/secret_token.rb` as plain text. This is a vulnerability because if, for example, you release your application as open source anyone can find the token and decrypt your sessions and sign their own cookies and generally cause havok. There are various schools of thought on how to fix this. For the example application I've put the token into an environment variable. In `config/initializers/secret_token.rb`:

```ruby
Sales::Application.config.secret_token = ENV['SECRET_TOKEN']
```

```bash
$ heroku config:add SECRET_TOKEN=some-secret-token
```

Running `brakeman` is similar to running `rails_best_practices`. Just invoke it from the root of your project to start a scan. I would again suggest creating a rake task to run `brakeman`. In `lib/tasks/security.rake`:

```ruby
task :brakeman do
  sh "brakeman -q -z"
end
```

### Running Security Scanners on Deploy

I usually create a task named `check` which runs tests, Brakeman, and Rails Best Practices all at the same time:

```ruby
task :check do
  Rake::Task['test'].invoke # could also be spec if you're using rspec
  Rake::Task['brakeman'].invoke
  Rake::Task['rails_best_practices'].invoke
end
```

In my projects I usually take this one step even farther and create a task named `deploy` which runs the `check` task before deploying the project. For the application that sells this book I have this task:

```ruby
task :deploy do
  Rake::Task['check'].invoke
  sh "git push origin master"
  sh "cap deploy"
end
```

This checks the code using the test suite and the two scanners, pushes it to my git server, and then deploys using Capistrano. I would advise having a task like this and always using it to deploy. That way you know you always have correct code running on the server.
