module AuthJwtGo
  class AuthorizedUser
    def initialize(fields)
      fields.each do |k, v|
        instance_variable_set("@#{k.to_s.underscore}", v)
        self.class.send(:attr_accessor, k.to_s.underscore)
      end
    end
  end
end
