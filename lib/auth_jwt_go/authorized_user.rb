module AuthJwtGo
  class AuthorizedUser
    def initialize(fields)
      fields.each do |key, value|
        self.define_singleton_method(key.to_s.underscore) { return value }
      end
    end
  end
end
