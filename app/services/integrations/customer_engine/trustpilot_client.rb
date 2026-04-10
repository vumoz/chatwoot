# frozen_string_literal: true

require 'faraday'

module Integrations
  module CustomerEngine
    # Trustpilot Business API — list reviews for a business unit.
    # Provide either oauth_access_token (recommended) or api_key + api_secret for client_credentials.
    # Ref: https://developers.trustpilot.com/
    class TrustpilotClient
      BASE = 'https://api.trustpilot.com/v1'

      def initialize(business_unit_id:, oauth_access_token: nil, api_key: nil, api_secret: nil)
        @business_unit_id = business_unit_id
        @oauth_access_token = oauth_access_token
        @api_key = api_key
        @api_secret = api_secret
      end

      def fetch_reviews(per_page: 100)
        url = "#{BASE}/business-units/#{@business_unit_id}/reviews"
        conn = Faraday.new do |f|
          f.adapter Faraday.default_adapter
        end
        response = conn.get(url) do |req|
          req.headers['Authorization'] = "Bearer #{bearer_token}"
          req.params['perPage'] = per_page
        end
        raise "Trustpilot HTTP #{response.status}: #{response.body}" unless response.success?

        data = JSON.parse(response.body)
        Array(data['reviews'] || data.dig('result') || data['items'] || [])
      end

      private

      def bearer_token
        @bearer_token ||= if @oauth_access_token.present?
                            @oauth_access_token
                          else
                            fetch_client_credentials_token!
                          end
      end

      def fetch_client_credentials_token!
        raise ArgumentError, 'Trustpilot api_key and api_secret required when oauth_access_token blank' if @api_key.blank? || @api_secret.blank?

        conn = Faraday.new(url: "#{BASE}/oauth/oauth-business-users-for-applications/accesstoken") do |f|
          f.request :url_encoded
          f.adapter Faraday.default_adapter
        end
        response = conn.post do |req|
          req.headers['Content-Type'] = 'application/x-www-form-urlencoded'
          req.body = {
            grant_type: 'client_credentials',
            client_id: @api_key,
            client_secret: @api_secret
          }
        end
        raise "Trustpilot OAuth HTTP #{response.status}: #{response.body}" unless response.success?

        JSON.parse(response.body)['access_token']
      end
    end
  end
end
