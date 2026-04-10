# frozen_string_literal: true

require 'faraday'

module Integrations
  module CustomerEngine
    # Shopify Admin REST — used to pull product catalog snippets as review-like monitoring signals.
    # Native star ratings vary by installed review apps; this baseline ingests product title/body text.
    # Ref: https://shopify.dev/docs/api/admin-rest
    class ShopifyAdminClient
      def initialize(shop_domain:, access_token:, api_version: '2024-10')
        @shop = shop_domain.to_s.sub(%r{\Ahttps?://}, '').sub(%r{/\z}, '')
        @token = access_token
        @version = api_version
      end

      def fetch_products(limit: 50)
        url = "https://#{@shop}/admin/api/#{@version}/products.json"
        conn = Faraday.new do |f|
          f.adapter Faraday.default_adapter
        end
        response = conn.get(url) do |req|
          req.headers['X-Shopify-Access-Token'] = @token
          req.params['limit'] = limit
        end
        raise "Shopify HTTP #{response.status}: #{response.body}" unless response.success?

        data = JSON.parse(response.body)
        Array(data['products'])
      end
    end
  end
end
