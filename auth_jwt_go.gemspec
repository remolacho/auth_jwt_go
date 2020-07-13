require_relative 'lib/auth_jwt_go/version'

Gem::Specification.new do |spec|
  spec.name          = "auth_jwt_go"
  spec.version       = AuthJwtGo::VERSION
  spec.authors       = ["jonathan rojas"]
  spec.email         = ["jonathangrh.25@gmail.com"]

  spec.summary       = %q{Auth API with Jwt include current_user helper}
  spec.description   = %q{this authenticates your api with jwt include current_user helper}
  spec.homepage      = 'https://github.com/remolacho/auth_jwt_go'

  spec.required_ruby_version = Gem::Requirement.new(">= 2.3.0")

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files         = Dir.chdir(File.expand_path('..', __FILE__)) do
    `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  end
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]
end
