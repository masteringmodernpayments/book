#!/usr/bin/env ruby

require 'sinatra'
require 'redcarpet'

@renderer = Redcarpet::Markdown.new(Redcarpet::Render::HTML)

get '/' do
  @content = @renderer.render(File.read('index.md'))
  erb :page
end
  
