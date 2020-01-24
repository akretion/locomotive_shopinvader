require 'jwt'

module ShopInvader
  module Middlewares

    # Endpoint returning a JWT token storing:
    # - the handle of the current site
    # - if authenticated, some information about the authenticated content entry
    #
    # Endpoint path: /locomotive_jwt (or locomotive_jwt.json)
    #
    # Returned JSON: { "token" => "<JWT token>" }
    #
    # Example of the payload of the JWT token:
    #
    # {
    #   "site_handle": "my-site",
    #   "account": {
    #     "_id": "42",
    #     "email": "john@doe.net"
    #   }
    # }
    #
    # Notes:
    # - by default, the _id and the email of the content entry are returned. For more attributes, use the attributes POST param.
    # - the secret and the validity of the token are stored under the authentication namespace of the site metafields.
    #   secret key name: jwt_secret, validity (in minutes) key name: jwt_validity
    #
    class Jwt

      ## constants ##
      ENDPOINT_PATH       = /\A\/locomotive_jwt(\.json)?/.freeze
      HASH_ALGORITHM      = 'HS256'.freeze
      DEFAULT_ATTRIBUTES  = %w(_id email).freeze

      def initialize(app)
        @app = app
      end

      def call(env)
        request = Rack::Request.new(env)

        if request.path_info =~ ENDPOINT_PATH && request.post?
          site, account = env.fetch('steam.site'), env.fetch('steam.authenticated_entry', nil)

          jwt = build_json_token(site, account, request.params['attributes'])

          [200, { 'Content-Type' => 'application/json' }, [{ token: jwt }.to_json]]
        else
          @app.call(env)
        end
      end

      private

      def build_json_token(site, account, attributes = nil)
        metafields  = site.metafields&.deep_symbolize_keys || {}
        exp         = Time.now.utc.to_i + site.metafields.dig(:authentication, :jwt_validity)&.to_i
        hmac_secret = site.metafields.dig(:authentication, :jwt_secret)
        attributes  = attributes || DEFAULT_ATTRIBUTES

        payload = { exp: exp, data: {
          site_handle:  site.handle,
          account:      account&.to_hash&.slice(*attributes)
        } }

        JWT.encode(payload, hmac_secret, HASH_ALGORITHM)
      end

    end

  end
end
