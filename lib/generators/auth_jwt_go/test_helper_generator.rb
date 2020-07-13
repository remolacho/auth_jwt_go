require 'rails/generators/base'
module AuthJwtGo
  module Generators

    class TestHelperGenerator < Rails::Generators::Base
      source_root File.expand_path('../templates', __FILE__)

      desc 'Creates a AuthJwt initializer'

      def test_initializer
        dir_name = 'spec/support'
        Dir.mkdir(dir_name) unless File.exists?(dir_name)
        copy_file 'request_helpers.rb', "#{dir_name}/request_helpers.rb"
      end
    end
  end
end
