require 'spec_helper'
require 'rack/test'

RSpec.describe ShopInvader::Middlewares::Jwt do

  include Rack::Test::Methods

  describe '/something-else' do
    it 'proceeds with the other rack middlewares' do
      post('/something-else', {}, {})
      expect(last_response.body).to eq('CONTENT')
    end
  end

  describe '/locomotive_jwt.json' do

    let(:secret)      { 'simplesecret' }
    let(:metafields)  { { authentication: { jwt_secret: secret, jwt_validity: 60 } } }
    let(:site)        { instance_double('Site', name: 'My awesome site', handle: 'my-awesome-site', metafields: metafields) }
    let(:env)         { { 'steam.site' => site } }
    let(:params)      { {} }

    subject { post('/locomotive_jwt.json', params, env); JSON.parse(last_response.body) }

    it 'returns a new JSON WEB TOKEN storing the information about the site' do
      data = extract_data_from_subject(subject)
      expect(data.dig('data', 'site_handle')).to eq('my-awesome-site')
      expect(data.dig('data', 'account')).to eq(nil)
    end

    context 'an account has been authenticated' do

      let(:account)   { instance_double('Account', _id: '42', name: 'John Doe', email: 'john@doe.net', to_hash: { '_id' => '42', 'name' => 'John Doe', 'email' => 'john@doe.net' }) }
      let(:env)       { { 'steam.site' => site, 'steam.authenticated_entry' => account } }

      it 'returns a new JSON WEB TOKEN storing the information about both the site and the authenticated account' do
        data = extract_data_from_subject(subject)
        expect(data.dig('data', 'account')).to eq({ '_id' => '42', 'email' => 'john@doe.net' })
      end

      describe 'asking for more information about the account' do

        let(:params) { { attributes: [:name, :email] } }

        it 'returns a new JSON WEB TOKEN including only the requested attributes for the authenticated account' do
          data = extract_data_from_subject(subject)
          expect(data.dig('data', 'account')).to eq({ 'name' => 'John Doe', 'email' => 'john@doe.net' })
        end

      end

    end

  end

  def app
    main_app = ->(env) { [200, {}, ['CONTENT']] }
    Rack::Builder.new do
      run ShopInvader::Middlewares::Jwt.new(main_app)
    end
  end

  def extract_data_from_subject(subject)
    decoded_token = JWT.decode(subject['token'], secret, true, { algorithm: 'HS256' })
    decoded_token.first
  end

end
