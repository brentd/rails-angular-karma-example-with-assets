This is an example Rails 3.2 application using Angular and Karma for testing.

It was modified from this repo: https://github.com/monterail/rails-angular-karma-example

We had trouble trying to get Karma to process asset pipeline assets. This fixes that by running the Rails application in a thread to serve assets rather than asking Karma to process them on the filesystem.
