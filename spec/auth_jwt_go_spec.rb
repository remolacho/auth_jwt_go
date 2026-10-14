require 'active_support/core_ext/object/blank'
require 'active_support/core_ext/string/inflections'

RSpec.describe AuthJwtGo do
  let(:secret) { 'test_secret' }

  before do
    AuthJwtGo.configure do |config|
      config.secret_key_jwt      = secret
      config.secret_key_api      = 'api_secret'
      config.algorithm           = nil
      config.class_name_model    = nil
      config.model_primary_key   = nil
      config.payload_primary_key = nil
    end
  end

  it 'has a version number' do
    expect(AuthJwtGo::VERSION).not_to be nil
  end

  describe '.encode' do
    it 'signs the payload with the configured secret and HS256 by default' do
      token = AuthJwtGo.encode(user_id: 1)
      payload, header = JWT.decode(token, secret, true, algorithm: 'HS256')

      expect(payload).to eq('user_id' => 1)
      expect(header['alg']).to eq('HS256')
    end

    it 'uses the configured algorithm' do
      AuthJwtGo.algorithm = 'HS512'
      header = JWT.decode(AuthJwtGo.encode(user_id: 1), secret, true, algorithm: 'HS512')[1]

      expect(header['alg']).to eq('HS512')
    end
  end

  describe '.decode' do
    let(:token) { AuthJwtGo.encode(user_id: 7, email: 'a@b.com') }

    it 'returns the payload from a raw token' do
      expect(AuthJwtGo.decode(token)).to eq('user_id' => 7, 'email' => 'a@b.com')
    end

    it 'accepts a "Bearer <token>" header value' do
      expect(AuthJwtGo.decode("Bearer #{token}")['user_id']).to eq(7)
    end

    it 'raises AuthJwtGo::DecodeError when the token is blank' do
      expect { AuthJwtGo.decode(nil) }.to raise_error(AuthJwtGo::DecodeError)
      expect { AuthJwtGo.decode('  ') }.to raise_error(AuthJwtGo::DecodeError)
    end

    it 'raises AuthJwtGo::VerificationError when the signature does not match' do
      forged = JWT.encode({ user_id: 7 }, 'other_secret', 'HS256')

      expect { AuthJwtGo.decode(forged) }.to raise_error(AuthJwtGo::VerificationError)
      expect { AuthJwtGo.decode(forged) }.to raise_error(AuthJwtGo::DecodeError)
    end

    it 'raises AuthJwtGo::ExpiredSignature when the token is expired' do
      expired = AuthJwtGo.encode(user_id: 7, exp: Time.now.to_i - 10)

      expect { AuthJwtGo.decode(expired) }.to raise_error(AuthJwtGo::ExpiredSignature)
    end

    it 'lets host apps rescue every failure with AuthJwtGo::DecodeError' do
      expired = AuthJwtGo.encode(user_id: 7, exp: Time.now.to_i - 10)

      expect { AuthJwtGo.decode(expired) }.to raise_error(AuthJwtGo::DecodeError)
    end
  end

  describe '.authorized_user_from' do
    it 'builds an AuthorizedUser from the payload' do
      user = AuthJwtGo.authorized_user_from("Bearer #{AuthJwtGo.encode(id: 3, enterprise: { token: 'abc' })}")

      expect(user).to be_a(AuthJwtGo::AuthorizedUser)
      expect(user.id).to eq(3)
      expect(user.enterprise).to eq('token' => 'abc')
    end
  end

  describe 'controller integration' do
    let(:controller_class) do
      Class.new do
        include AuthJwtGo
        attr_reader :rendered
        attr_accessor :headers

        def initialize(headers = {})
          @headers = headers
        end

        def request
          Struct.new(:headers).new(@headers)
        end

        def render(json:, status:)
          @rendered = { json: json, status: status }
        end

        public :current_user
      end
    end

    describe '#authorized_app' do
      it 'renders 401 when Api-Token does not match' do
        controller = controller_class.new('Api-Token' => 'wrong')
        controller.authorized_app

        expect(controller.rendered[:status]).to eq(401)
      end

      it 'does not render when Api-Token matches' do
        controller = controller_class.new('Api-Token' => 'api_secret')
        controller.authorized_app

        expect(controller.rendered).to be_nil
      end
    end

    describe '#authorized_user' do
      it 'sets current_user from a valid Bearer token' do
        controller = controller_class.new('Authorization' => "Bearer #{AuthJwtGo.encode(id: 9)}")
        controller.authorized_user

        expect(controller.rendered).to be_nil
        expect(controller.current_user.id).to eq(9)
      end

      it 'renders 403 when the header has no "Bearer" prefix' do
        controller = controller_class.new('Authorization' => AuthJwtGo.encode(id: 9))
        controller.authorized_user

        expect(controller.rendered[:status]).to eq(403)
      end

      it 'renders 403 when the token is missing' do
        controller = controller_class.new
        controller.authorized_user

        expect(controller.rendered[:status]).to eq(403)
      end

      it 'renders 403 when the token is expired' do
        expired = AuthJwtGo.encode(id: 9, exp: Time.now.to_i - 10)
        controller = controller_class.new('Authorization' => "Bearer #{expired}")
        controller.authorized_user

        expect(controller.rendered[:status]).to eq(403)
      end
    end

    describe '#encode_token' do
      it 'wraps the token in a hash' do
        result = controller_class.new.encode_token(id: 1)

        expect(AuthJwtGo.decode(result[:jwt])).to eq('id' => 1)
      end
    end

    describe '#decoded_tenant' do
      let(:http_request) { ->(value) { Struct.new(:env).new({ 'HTTP_AUTHORIZATION' => value }) } }

      it 'returns an AuthorizedUser for a valid token' do
        user = controller_class.new.decoded_tenant(http_request.("Bearer #{AuthJwtGo.encode(id: 4)}"))

        expect(user.id).to eq(4)
      end

      it 'returns an ExpiredSignature error hash for an expired token' do
        expired = AuthJwtGo.encode(id: 4, exp: Time.now.to_i - 10)
        result = controller_class.new.decoded_tenant(http_request.("Bearer #{expired}"))

        expect(result).to include(error: true)
        expect(result[:message]).to start_with('JWT::ExpiredSignature')
      end
    end
  end
end
