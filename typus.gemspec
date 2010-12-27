# -*- encoding: utf-8 -*-

$LOAD_PATH << File.join(File.dirname(__FILE__), 'lib')
require 'typus/version'

Gem::Specification.new do |s|
  s.name = "typus"
  s.version = Typus::VERSION
  s.date = Time.now.strftime('%Y-%m-%d')

  s.platform = Gem::Platform::RUBY
  s.authors = ["Francesc Esplugas"]
  s.email = ["core@typuscms.com"]
  s.homepage = "http://core.typuscms.com/"
  s.summary = "Effortless backend interface for Ruby on Rails applications. (Admin scaffold generator)"
  s.description = "Awesome admin scaffold generator for Ruby on Rails applications."

  s.required_rubygems_version = ">= 1.3.6"
  s.rubyforge_project = "typus"

  s.files = Dir.glob('**/*') - Dir.glob('test/**/*')  - Dir.glob('docs/**/*') - ['typus.gemspec']
  s.require_path = "lib"

  s.add_dependency "fastercsv", "1.5.3" if RUBY_VERSION < '1.9'
  s.add_dependency "will_paginate", "~> 3.0.pre2"
end
