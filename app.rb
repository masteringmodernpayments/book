#!/usr/bin/env ruby

require 'sinatra'
require 'redcarpet'

RENDERER = Redcarpet::Markdown.new(Redcarpet::Render::HTML)

get '/' do
  @content = RENDERER.render(File.read('index.md'))
  erb :page
end
  
