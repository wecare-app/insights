ENV['BUNDLE_GEMFILE'] ||= File.expand_path('../Gemfile', __dir__)

# Ruby 3.2+ com Rails 6.1: garante que Logger esteja carregado antes do ActiveSupport
# (concurrent-ruby recente não faz mais o autoload de Logger).
require "logger"

require "bundler/setup" # Set up gems listed in the Gemfile.
require "bootsnap/setup" # Speed up boot time by caching expensive operations.
