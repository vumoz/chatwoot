# frozen_string_literal: true

module CustomerEngine
  class Connector < ApplicationRecord
    self.table_name = 'customer_engine_connectors'

    PROVIDERS = %w[
      zendesk yelp_fusion google_business
      trustpilot intercom shopify amazon_selling_partner
    ].freeze

    belongs_to :account

    enum status: { disabled: 0, enabled: 1 }

    validates :account_id, presence: true
    validates :name, presence: true
    validates :provider, presence: true, inclusion: { in: PROVIDERS }
    validate :validate_settings_for_provider

    before_validation :normalize_settings

    def as_json(options = {})
      h = super(options)
      h['settings'] = mask_settings(settings)
      h
    end

    private

    def mask_settings(raw)
      secrets = %w[
        api_token api_key oauth_refresh_token oauth_client_secret partner_r2r_access_token
        oauth_access_token access_token intercom_access_token shopify_access_token lwa_client_secret aws_secret_access_key
      ]
      h = raw.stringify_keys
      h.each_key do |k|
        h[k] = "****#{h[k].to_s.last(4)}" if secrets.include?(k) && h[k].present?
      end
      h
    end

    def normalize_settings
      self.settings = {} if settings.nil?
      self.settings = settings.deep_stringify_keys
    end

    def validate_settings_for_provider
      case provider
      when 'zendesk'
        errors.add(:settings, 'subdomain required') if settings['subdomain'].blank?
        errors.add(:settings, 'email required') if settings['email'].blank?
        errors.add(:settings, 'api_token required') if settings['api_token'].blank?
      when 'yelp_fusion'
        errors.add(:settings, 'api_key required') if settings['api_key'].blank?
        errors.add(:settings, 'business_id required') if settings['business_id'].blank?
      when 'google_business'
        errors.add(:settings, 'oauth_client_id required') if settings['oauth_client_id'].blank?
        errors.add(:settings, 'oauth_client_secret required') if settings['oauth_client_secret'].blank?
        errors.add(:settings, 'oauth_refresh_token required') if settings['oauth_refresh_token'].blank?
        errors.add(:settings, 'account_resource_name required') if settings['account_resource_name'].blank?
        errors.add(:settings, 'location_resource_name required') if settings['location_resource_name'].blank?
      when 'trustpilot'
        errors.add(:settings, 'business_unit_id required') if settings['business_unit_id'].blank?
        if settings['oauth_access_token'].blank? && (settings['api_key'].blank? || settings['api_secret'].blank?)
          errors.add(:settings, 'oauth_access_token or api_key+api_secret required')
        end
      when 'intercom'
        errors.add(:settings, 'access_token required') if settings['access_token'].blank?
      when 'shopify'
        errors.add(:settings, 'shop_domain required') if settings['shop_domain'].blank?
        errors.add(:settings, 'access_token required') if settings['access_token'].blank?
      when 'amazon_selling_partner'
        unless ActiveModel::Type::Boolean.new.cast(settings['stub_mode'])
          errors.add(:settings, 'stub_mode must be true until Amazon SP-API ingestion is configured')
        end
      end
    end
  end
end
