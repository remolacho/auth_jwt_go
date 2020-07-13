require 'rails/generators/base'
module AuthJwtGo
  module Generators

    class InstallGenerator < Rails::Generators::Base
      source_root File.expand_path('../templates', __FILE__)

      desc 'Creates a AuthJwt initializer'

      def copy_initializer
        copy_file 'init_auth_jwt.rb', 'config/initializers/init_auth_jwt.rb'
      end
    end
  end
end