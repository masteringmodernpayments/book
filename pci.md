---
discussion_issue: 4
---

# Security and PCI Compliance

[pci-pci]: https://www.pcisecuritystandards.org
[pci-stripe_pci]: https://stripe.com/help/security
[pci-rsa]: http://en.wikipedia.org/wiki/RSA_(algorithm)
[pci-namecheap_ssl]: http://www.namecheap.com/ssl-certificates.aspx
[pci-heroku_ssl]: https://devcenter.heroku.com/articles/ssl-endpoint
[pci-rbp]: http://rails-bestpractices.com
[pci-brakeman]: http://brakemanscanner.org
[pci-cochrane]: http://kencochrane.net/blog/2012/01/developers-guide-to-pci-compliant-web-applications/
[pci-code-climate]: https://codeclimate.com

* Learn about PCI compliance
* Generate and install an SSL certificate
* Set up Rails security tools

---

<i>Note: I'm not an expert in PCI compliance and this chapter shouldn't be interpreted as legal advice. Rather, this is background information and advice on how to implement Stripe's guidelines. If you have questions, please ask Stripe or your nearest local PCI consultant.</i>

In 2004 some of the big credit card processing companies, including Mastercard, Visa, and Discover, all started putting together security standards that their merchants would have to agree to abide by if they wanted to charge cards. This included things like what information from a card you can and can't store and what types of security your systems would have to have.

By 2006 the whole industry had joined up and published version 1 of the [Payment Card Industry Data Security Standards][pci-pci] (PCI-DSS). Every credit card processor put language in their merchant agreement that bound each merchant to abiding by PCI-DSS. Security breaches from things that PCI-DSS prevents lead to audits and possibly dropping your account and getting put on an industry-wide blacklist.

## Developer's Guide

One of the best resources that I've found that talks about all of these requirements is Ken Cochrane's [Developers Guide to PCI Compliant Web Applications][pci-cochrane]. He goes into quite a bit of depth on the various rules, regulations, and mitigation strategies that are out there. Most of the advice is platform-agnostic but some is Django-specific. All of it is great.

## Stripe and PCI

The really revolutionary part of how Stripe works is in how they [reduce your compliance scope][pci-stripe_pci] as a merchant. Let's walk through a transaction on a page that doesn't use Stripe.

1. Enter your card information into a normal HTML.
1. This form POSTs to the merchant's server
1. The merchant's software passes the credit card information to their *gateway service*
1. The gateway service talks to all of the various banks involved.
1. When a transaction is approved by the bank, the gateway eventually deposits the money into the *merchant account*.

There's quite a few attack surfaces here. By far the most common was for an attacker to exploit a bug in the merchant's application and get into their database. Once they're in the database, an attacker would have free-range to copy credit card information.

Another attack vector would be to listen in on an unencrypted wifi network and wait for someone to put their card information into a non-encrypted web page, which was also common before PCI-DSS came onto the scene.

Stripe makes both of these attacks, along with many more, irrelevant with their tokenization process. When you create a form using `stripe.js` or Stripe Checkout loaded from Stripe's servers none of your customer's credit card info is sent through your servers.
Instead, Stripe's JavaScript sends that info to their servers over HTTPS where they turn it into a single-use *token*. This token is injected into your form and sent to your server which can use it to refer to a customer's credit card without ever having seen it.

The only thing you as a merchant have to do to be PCI compliant according to Stripe is to make sure you're serving up your payment-related pages over HTTPS and ensure they use `stripe.js` or Stripe Checkout. We've already talked about Checkout and we'll cover `stripe.js` in the chapter on Custom Forms. Let's talk about setting up HTTPS.

## Implementing HTTPS with Rails

Rails after v3.1 makes forcing visitors to HTTPS incredibly easy. In `config/environments/production.rb`:

```ruby
config.force_ssl = true
```

This will redirect all non-HTTPS requests to HTTPS automatically on production and sets the `Strict-Transport-Security` header which tells the customer's browser to always use HTTPS. It also ensures that all cookies get the `secure` flag.

For this example `force_ssl` is all we need to do because Heroku provides what's called a "wildcard ssl certificate" for all apps accessed at `herokuapp.com`. The disadvantage of using Heroku's free certificate is that you're constrained to using `yourapp.herokuapp.com`.

If you want to use your own URL you'll need to get your own certificate (generally around $10 per year) and install it with Heroku which will cost $20 per month.

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

OpenSSL will ask you a bunch of questions now. Fill them in like the prompts, but when you get to the `Common Name` question, use the exact name of web server. Note that this really does have to be an exact match, so if you want to secure, say, `www.example.com`. that's what you should use. Putting just `example.com` won't work. You can also create what's called a *wildcard certificate* which will secure all of the subdomains for a given parent domain by setting `*.example.com` for the `Common Name`. This is much more expensive than single domain certificates, of course.

Also, make sure to leave extra attributes, including the challenge password, blank.

### Validate your new CSR

```bash
$ openssl req -noout -text -in example.com.csr
```

This will print out a bunch of information about your certificate. You can ignore almost all of it, but pay attention to the line `CN=example.com`. This should match what you put in for your server name in the `Common Name` field.

### Buy the actual certificate

Head on over to [Namecheap's SSL page][pci-namecheap_ssl]. Here you're presented with a bunch of different options in what they feel is least-secure to most-secure list. I generally buy the cheapest option because they're all pretty much the same in the $10 range.

Another option is to go through Extended Verification (EV), which involves quite a bit more paperwork, time, and money. The benefit is that your customers will see a green bar in Firefox and Safari with your company name instead of the URL. This increases customer confidence that you are who you say you are.

For now, let's just get the cheapest Comodo certificate.

Go through checkout and pay and you'll get sent to a page where you can pick your server type and paste your CSR. For Heroku you should choose the "Other" option in the server dropdown. Open your CSR up and paste the entire contents into the text box, then hit Next.

Namecheap will give you a list of email addresses to choose from. This is where it's going to send the verification email that contains a link you have to click to proceed through the process. If you don't already have one of these email aliases set up, you should do so now before picking one and clicking Next.

You'll now be prompted to enter your administrative contact info, which it helpfully copied from your domain registration if you registered through Namecheap. Fill this stuff out, then hit Next.

You'll get taken to a web page with a handy dandy flow chart, and within a few minutes you'll get an email. Click the link in the email, copy and paste the verification code, and hit the "Next" button. You'll get another email, this one with your new certificate attached.

### Installing the certificate at Heroku

Now that you have your bright shiny new certificate you'll need to attach it to your application. With Heroku, [this is easy][pci-heroku_ssl].

```bash
$ heroku addons:add ssl:endpoint
$ heroku certs:add www.example.com.crt bundle.pem example.com.key
```

To see if the certificate installed properly:

```bash
$ heroku certs
```

Now just configure `www.example.com` as a CNAME pointing at the `herokussl.com` endpoint printed by `heroku certs` and test it out:

```bash
$ curl -kvI https://www.example.com
```

This should print out a bunch of stuff about SSL and the headers from your application. If things didn't work properly it'll give you errors and hints on how to fix them.

## Rails Security Tools

There are a few other tools you can use help ensure that your Rails application is secure, above and beyond requiring HTTPS. Adhering to Rails best practices and making sure you don't accidentally introduce known attack vectors into your code are two of the lowest-effort things you can do to make your app secure.

### Rails Best Practices

[Rails Best Practices][pci-rbp] is a website where people can submit and upvote various practices that help to keep your app safe and secure, and help structure your code in a maintainable way. Conveniently, Rails Best Practices also publishes a gem that automatically checks your app against more than fourty of the most common best practices. To install it, add it to the `Gemfile`:

```ruby
group :development do
  gem 'rails_best_practices'
end
```

You should add a rake task to simplfy running it. In `lib/tasks/security.rake`:

```ruby
task :rails_best_practices do
  path = File.expand_path("../../../", __FILE__)
  sh "rails_best_practices #{path}"
end
```
 
The Rails scaffolding tends to produce code that doesn't adhere to these practices. Most notably it uses instance variables inside partials and it generates verbose render statements inside forms. The fix is pretty easy. Change this:

```rhtml
<%= form_for @object do |f| %>
  <%= f.text_input :attribute %>
<% end %>
```

```rhtml
<%= render 'form' %>
```

To this:

```rhtml
<%= form_for object do |f| %>
  <%= f.text_input :attribute %>
<% end %>
```

```rhtml
<%= render 'form', object: @object %>
```

In more recent versions of Rails `render` is a lot smarter than it used to be. It knows based on context what we mean by the second argument. We also don't have to specify the `locals:` key anymore, it's just implied that the second argument is the locals hash when rendering a partial.

### Brakeman

[Brakeman][pci-brakeman] is a security static analysis scanner for Rails applications. It goes through your code looking for known security vulnerabilities and suggests fixes. The default Rails application, in fact, ships with one of these vulnerabilities: Rails generates a "secret key base" that it uses to encrypt session information and sign cookies so users can't modify it. By default, it sticks this token into `config/initializers/secret_token.rb` as plain text. This is a vulnerability because if, for example, you release your application as open source anyone can find the token and decrypt your sessions and sign their own cookies and generally cause havok. One way to mitigate this vulnerability is to put the secret key base in an environment variable. In `config/initializers/secret_token.rb`:

```ruby
Sales::Application.config.secret_key_base = ENV['SECRET_KEY_BASE']
```

```bash
$ heroku config:add SECRET_KEY_BASE=some-long-random-string
```

Installing and running `brakeman` is similar to `rails_best_practices`. Just install it and invoke it from the root of your project to start a scan. In `Gemfile`:

```ruby
gem 'brakeman'
```

You can create a rake task to run `brakeman` too. In `lib/tasks/security.rake`:

```ruby
task :brakeman do
  sh "brakeman -q -z"
end
```

The `-q` option tells `brakeman` to be suppress informational and `-z` tells it to treat warnings as errors.

### Running Security Scanners on Deploy

I have found it helpful to create task named `check` which runs tests, Brakeman, and Rails Best Practices all at the same time:

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
  sh "git push origin heroku"
end
```

This checks the code using the test suite and the two scanners and then pushes it to heroku. You should have a task like this and always use it to deploy. That way you know you always have correct code running on the server.

### Code Climate

A service named [Code Climate][pci-code-climate] wraps both both Rails Best Practices and Brakeman up into an automated service that hooks into your GitHub account. Every time you push, Code Climate will pick up the change and analyze it for known bugs, security issues, and code cleanliness problems, and then email you a report. I highly recommend it if you are working with more than just yourself and if you're using GitHub mosting. It's well worth the price.

