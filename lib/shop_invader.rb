require 'locomotive/steam'
require 'locomotive/steam/server'
require 'algoliasearch'

require 'shop_invader/version'
require 'shop_invader/errors'
require 'shop_invader/services'
require 'shop_invader/services/algolia_service'
require 'shop_invader/services/erp_service'
require 'shop_invader/services/action_service'
require 'shop_invader/middlewares/templatized_page'
require 'shop_invader/middlewares/erp_proxy'
require 'shop_invader/middlewares/store'
require 'shop_invader/middlewares/renderer'
require 'shop_invader/middlewares/locale'
require 'shop_invader/middlewares/snippet'
require 'shop_invader/middlewares/helpers'
require_relative_all %w(concerns concerns/sitemap), 'shop_invader/middlewares'
require_relative_all %w(. drops filters tags tags/concerns), 'shop_invader/liquid'
require 'shop_invader/steam_patches'
require 'faraday'

module ShopInvader

  # Locales mapping table. Locomotive only uses the
  # main locale but not the dialect. This behavior
  # might change in Locomotive v4.
  LOCALES = {
    'en' => 'en_US',
    'de' => 'de_DE',
    'fr' => 'fr_FR',
    'bg' => 'bg_BG',
    'cs' => 'cs_CZ',
    'da' => 'da_DK',
    'el' => 'el_GR',
    'es' => 'es_ES',
    'ca' => 'it_IT',
    'fa-IR' => 'fa_IR',
    'fi-FI' => 'fi_FI',
    'it' => 'it_IT',
    'ja-JP' => 'ja_JP',
    'lt' => 'lt_LT',
    'nl' => 'nl_NL',
    'pl-PL' => 'pl_PL',
    'pt' => 'pt_PT',
    'pt-BR' => 'it_IT',
    'ru' => 'ru_RU',
    'sv' => 'sv_SE',
    'uk' => 'uk_UA',
    'zh-CN' => 'zh_CN',
    'et' => 'et_EE',
    'hr' => 'hr_HR',
    'nb' => 'nb_NO',
    'sk' => 'sk_SK',
    'sl' => 'sl_SL',
    'sr' => 'sr_RS',
  }

  def self.setup
    Locomotive::Steam.configure do |config|
      config.middleware.insert_after Locomotive::Steam::Middlewares::TemplatizedPage, ShopInvader::Middlewares::TemplatizedPage
      config.middleware.insert_before Locomotive::Steam::Middlewares::Path, ShopInvader::Middlewares::Store
      config.middleware.insert_after Locomotive::Steam::Middlewares::Path, ShopInvader::Middlewares::ErpProxy
      config.middleware.insert_after Locomotive::Steam::Middlewares::Path, ShopInvader::Middlewares::SnippetPage
    end

    subscribe_to_steam_notifications
  end

  def self.subscribe_to_steam_notifications

    def is_erp_customer(payload)
      payload[:request].env['steam.site'].metafields.include?('erp') && payload[:entry].content_type.name == 'customers'
    end

    # new signups
    ActiveSupport::Notifications.subscribe('steam.auth.signed_up') do |name, start, finish, id, payload|
      if payload[:request].env['steam.site'].metafields.include?('erp') && payload[:entry].content_type.name == 'customers'
        request = payload[:request]
        entry = payload[:entry]
        service = Locomotive::Steam::Services.build_instance(payload[:request])
        params = request.params.clone
        params.update({
            'external_id': entry._id,
            'email': entry.email
            })

        %w(auth_action auth_disable_email auth_content_type auth_id_field
           auth_password_field auth_email_handle auth_callback auth_entry).each do | key |
          params.delete(key)
        end
        rollback = false
        begin
          if params.include?('auth_guest_signup')
            register_params = {
              'external_id': entry._id,
              # TODO it will be better to not pass this arg, we will discusse about it
              # on odoo side then remove this comment of teh email here
              'email': entry.email
            }
            data = service.erp.call('POST', 'guest/register', register_params)
          else
            data = service.erp.call('POST', 'customer', params)
          end
        rescue ShopInvader::ErpMaintenance => e
          request.env['steam.liquid_assigns']['store_maintenance'] = true
          rollback = true
        else
          if data.include?(:error)
            rollback = true
          else
            unless data.include?('role')
              data['role'] = request.env['steam.site'].metafields['erp']['default_role']
            end
            vals = {}
            current_vals = entry.to_hash
            data.each do |key, val|
              if current_vals.include?(key) && current_vals[key] != data[key]
                vals[key] = val
              end
            end
            service.content_entry.update_decorated_entry(entry, vals)
          end
        end
        if rollback
          # Drop the content created (no rollback on mongodb)
          service.content_entry.delete(entry.content_type_slug, entry._id)
          # Add a fake error field to avoid content authentification
          entry.errors.add('error', 'Fail to create')
        end
      end
    end

    ActiveSupport::Notifications.subscribe('steam.auth.signed_in') do |name, start, finish, id, payload|
      if payload[:request].env['steam.site'].metafields.include?('erp') && payload[:entry].content_type.name == 'customers'
        service = Locomotive::Steam::Services.build_instance(payload[:request])
        payload[:request].env['authenticated_entry'] = payload[:entry]
        begin
          service.erp.initialize_customer
        rescue ShopInvader::ErpMaintenance => e
          # TODO add special logging
        end
      end
    end

    ActiveSupport::Notifications.subscribe('steam.auth.reset_password') do |name, start, finish, id, payload|
      if payload[:request].env['steam.site'].metafields.include?('erp') && payload[:entry].content_type.name == 'customers'
        service = Locomotive::Steam::Services.build_instance(payload[:request])
        payload[:request].env['authenticated_entry'] = payload[:entry]
        begin
          service.erp.initialize_customer
        rescue ShopInvader::ErpMaintenance => e
          # TODO add special logging
        end
      end
    end

    ActiveSupport::Notifications.subscribe('steam.auth.signed_out') do |name, start, finish, id, payload|
      # After signed out, drop the full session
      # We should move this code in a dedicated service
      session = payload[:request].env['rack.session']
      session.keys.each do | key |
        if key.start_with?('store_')
            cookie_key = key.gsub('store_', '')
            payload[:request].env['steam.cookies'][cookie_key] = {value: '', path: '/', max_age: 0}
        end
      end
      session = {}
    end
  end
end

# The Rails app must call the setup itself.
unless defined?(Rails)
  # context here: Wagon site
  ShopInvader.setup
end
