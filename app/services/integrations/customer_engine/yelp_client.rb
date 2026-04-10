# frozen_string_literal: true

# Yelp Fusion API: read-only business reviews (fetch). Public owner replies use
# Integrations::CustomerEngine::YelpPartnerClient (Respond to Reviews / partner-api).

require 'faraday'

module Integrations
  module CustomerEngine
    class YelpClient
      BASE = 'https://api.yelp.com/v3'

      def initialize(api_key:)
        @api_key = api_key
      end

      def fetch_reviews(business_id)
        conn = Faraday.new(url: BASE) do |f|
          f.adapter Faraday.default_adapter
        end
        response = conn.get("/businesses/#{business_id}/reviews") do |req|
          req.headers['Authorization'] = "Bearer #{@api_key}"
          req.params['limit'] = 50
        end
        raise "Yelp HTTP #{response.status}: #{response.body}" unless response.success?

        data = JSON.parse(response.body)
        Array(data['reviews'])
      end
    end
  end
end
