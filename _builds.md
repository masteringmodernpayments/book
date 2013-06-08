# Building Artifacts

Note: none of this is actually implemented yet.

Desired artifacts:

* Website (actually an app where users can login and search and view the guide)
* Downloadable HTML
* PDF
* Mobi
* ePub

Implementation details

* Use a Rails app that includes the sales engine to actually sell access to the guide
* App deploy checks out the latest version of the guide, does document conversion on the fly
* Customers get an email with no-login links to download (actually generate) the book as well
  as a link to create a login to the site for searchable access and updates

This means that I'm going to have to actually factor everything out into a resuable engine, which means I'm going to need to actually write tests and then I might as well sell the damn thing.
