require 'hubspot-api-client'

Hubspot.configure do |config|
    config.access_token = ENV["HUBSPOT_ACCESS_TOKEN"]
  end