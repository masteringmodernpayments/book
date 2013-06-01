#!/usr/bin/env ruby

require 'sinatra'

@renderer = Redcarpet::Markdown.new(Redcarpet::Render::HTML)

get '/' do
  @content = @renderer.render(File.read('index.md'))
  erb :page
end
  
