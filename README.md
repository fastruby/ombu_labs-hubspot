# OmbuLabs::Hubspot
Source code for OmbuLabs Hubspot integration

## Usage
Create a Hubspot client instance:

```ruby
module Hubspot
  INSTANCE_MUTEX = Mutex.new
  def self.client
    return @client if defined?(@client) && @client
    INSTANCE_MUTEX.synchronize do
      @client ||= Hubspot::Client.new(access_token: ENV["HUBSPOT_ACCESS_TOKEN"], auth_names: "oauth2")
    end
  end
end
```

Then you can use the `Hubspot.client` to interact with the Hubspot API.

## Installation
Add this line to your application's Gemfile:

```ruby
gem 'ombu_labs-hubspot'
```

And then execute:
```bash
$ bundle
```

Or install it yourself as:
```bash
$ gem install ombu_labs-hubspot
```

## Contributing
Contribution directions go here.

## License
The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
