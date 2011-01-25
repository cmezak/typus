source 'http://rubygems.org'

gemspec

gem 'acts_as_list'
gem 'acts_as_tree'
gem 'dragonfly', '~>0.8.1'
gem 'factory_girl'
gem 'paperclip'
gem 'rack-cache', :require => 'rack/cache'
gem 'rails', '~> 3.0'

group :test do
  gem 'rspec-rails', :require => false
  gem 'shoulda'
  gem 'syntax', :require => false
  gem 'tartare', :git => 'https://github.com/fesplugas/rails-tartare.git', :require => false

  gem 'mocha'
end

group :development, :test do

  platforms :jruby do
    gem 'activerecord-jdbc-adapter', :require => false
    # gem 'activerecord-jdbcpostgresql-adapter'
    gem 'jdbc-mysql'
    gem 'jdbc-postgres'
    gem 'jdbc-sqlite3'
  end

  platforms :ruby do
    gem 'mysql2'
    gem 'pg'
    gem 'sqlite3-ruby', :require => 'sqlite3'
  end

end

group :production do

  platforms :jruby do
    gem 'activerecord-jdbc-adapter'
    gem 'jdbc-sqlite3'
  end

  platforms :ruby do
    gem 'sqlite3-ruby', :require => 'sqlite3'
  end

end
