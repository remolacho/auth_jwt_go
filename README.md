# AuthJwtGo

This gem allows you to make identifications for your microservices and create the Jwt if you wish so

## Installation

Add this line to your application's Gemfile:

```ruby
  gem 'auth_jwt_go', '~> 1.0'
```
The `jwt` gem is installed automatically as a dependency, you don't need to add it to your Gemfile.

And then execute:

    $ bundle install

Or install it yourself as:

    $ gem install auth_jwt_go

## Usage

  Once installed run the following commands:
  
   1- It will create a file in the initializer so you can configure the parameters

     rails g auth_jwt_go:install
   
   2- Create a helper in the spec support to handle authentication tests
     
     rails g auth_jwt_go:test_helper

   3- In your main controller or base you must add the module
   
     include AuthJwtGo
     
     Example
     class ApiController < ActionController::API
       include AuthJwtGo
     end

   4- You can use two methods for accessing your API
   
     before_action :authorized_app
     before_action :authorized_user
    
     Example
     class ApiController < ActionController::API
       include AuthJwtGo
       
       before_action :authorized_app # Authenticate the client app
       before_action :authorized_user # Identify the user based on the jwt for login
     end
    
   5- rspec add in rspec_rails
       config.include RequestHelpers, type: :controller
 
## Encoding and decoding tokens outside controllers

The gem exposes module methods that use the configured `secret_key_jwt` and `algorithm`, so you never need to call the `jwt` gem directly (Sidekiq middlewares, jobs, services, specs):

```ruby
token = AuthJwtGo.encode(user_id: user.id, exp: 1.day.from_now.to_i)
# => "eyJhbGciOiJIUzI1NiJ9..."

AuthJwtGo.decode(token)               # => { "user_id" => 1, "exp" => 1700000000 }
AuthJwtGo.decode("Bearer #{token}")   # the "Bearer " prefix is optional

user = AuthJwtGo.authorized_user_from(token)
user.user_id                          # => 1
```

`decode` and `authorized_user_from` raise `AuthJwtGo::ExpiredSignature` for expired tokens, `AuthJwtGo::VerificationError` when the signature does not match, and `AuthJwtGo::DecodeError` for any other invalid or missing token. Both are subclasses of `DecodeError`, so rescuing `AuthJwtGo::DecodeError` catches all of them. They can also be used with `rescue_from`:

```ruby
begin
  Current.user = AuthJwtGo.authorized_user_from(job['current_jwt'])
rescue AuthJwtGo::DecodeError => e
  Rails.logger.warn("Invalid JWT: #{e.message}")
end
```

## include helper current_user 
 
## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/remolacho/auth_jwt_go.
