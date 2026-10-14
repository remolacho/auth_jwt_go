require 'jwt'
require 'auth_jwt_go/version'
require 'auth_jwt_go/authorized_user'

module AuthJwtGo
  DEFAULT_ALGORITHM = 'HS256'

  # Re-exported so host apps can rescue them without referencing the jwt gem.
  # ExpiredSignature and VerificationError inherit from DecodeError, so rescuing DecodeError catches all.
  DecodeError       = JWT::DecodeError
  ExpiredSignature  = JWT::ExpiredSignature
  VerificationError = JWT::VerificationError

  class << self
    attr_accessor  :secret_key_api,
                   :secret_key_jwt,
                   :algorithm,
                   :class_name_model,
                   :model_primary_key,
                   :payload_primary_key
  end

  def self.configure(&block)
    yield self
  end

  # Signs a payload with the configured secret and algorithm.
  #   AuthJwtGo.encode(user_id: 1, exp: 1.day.from_now.to_i) # => "eyJhbGciOi..."
  def self.encode(payload)
    JWT.encode(payload, secret_key_jwt, algorithm || DEFAULT_ALGORITHM)
  end

  # Verifies a token and returns its payload as a Hash with string keys.
  # Accepts the raw token or the full header value ("Bearer <token>").
  # Raises AuthJwtGo::ExpiredSignature or AuthJwtGo::DecodeError when invalid or missing.
  #   AuthJwtGo.decode("Bearer eyJhbGciOi...") # => { "user_id" => 1, ... }
  def self.decode(token)
    raw = token.is_a?(String) ? token.split(' ').last : token
    JWT.decode(raw, secret_key_jwt, true, { algorithm: algorithm || DEFAULT_ALGORITHM })[0]
  end

  # Same as decode, but wraps the payload in an AuthorizedUser.
  #   AuthJwtGo.authorized_user_from(job['current_jwt']).enterprise
  def self.authorized_user_from(token)
    AuthorizedUser.new(decode(token))
  end

  def authorized_user
    render json: { message: 'The user has not token active' }, status: 403 unless logged_in?
  rescue StandardError => e
    render json: { message: "The error was #{e.to_s}" }, status: 500
  end

  def authorized_app
    unless AuthJwtGo::secret_key_api.eql?(auth_client)
      render json: {message: 'The app has not access' }, status: 401
    end
  end

  def decoded_tenant(http_request)
    return { message: 'The jwt can not decode!!!!', error: true } unless http_request.env["HTTP_AUTHORIZATION"]
    AuthJwtGo.authorized_user_from(bearer_token(http_request.env["HTTP_AUTHORIZATION"]))
  rescue JWT::ExpiredSignature => e
    { message: "JWT::ExpiredSignature => #{e.to_s}", error: true }
  rescue JWT::DecodeError => e
    { message: "JWT::DecodeError => #{e.to_s}", error: true }
  end

  def encode_token(payload)
    return  { message: 'The payload is not present'} unless payload.present?
    { jwt: AuthJwtGo.encode(payload) }
  end

  private

  def logged_in?
    !!logged_in_user
  end

  def logged_in_user
    payload = decoded_token
    return unless payload

    default_field = 'id'
    field_payload = AuthJwtGo::payload_primary_key.presence || default_field
    field_model   = AuthJwtGo::model_primary_key.presence || default_field

    @current_user = if AuthJwtGo::class_name_model.present?
                      AuthJwtGo::class_name_model.classify.constantize.find_by(field_model => payload[field_payload])
                    else
                      AuthJwtGo::AuthorizedUser.new(payload)
                    end
  end

  def decoded_token
    return unless auth_jwt.present?
    AuthJwtGo.decode(bearer_token(auth_jwt))
  rescue JWT::DecodeError
    nil
  end

  # Controllers only accept the "Bearer <token>" format.
  def bearer_token(header_value)
    header_value.to_s.split(' ')[1]
  end

  # { Authorization: 'Bearer <token>' }
  def auth_jwt
    request.headers['Authorization']
  end

  def auth_client
    request.headers['Api-Token']
  end

  def current_user
    @current_user
  end
end