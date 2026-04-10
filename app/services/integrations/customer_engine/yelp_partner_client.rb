# frozen_string_literal: true

require 'faraday'

module Integrations
  module CustomerEngine
    # Yelp "Respond to Reviews" (Partner API). Requires a business-owner OAuth token
    # with R2R access (see https://docs.developer.yelp.com/docs/respond-to-reviews-api-v2).
    class YelpPartnerClient
      PARTNER_API_ROOT = 'https://partner-api.yelp.com'

      def initialize(access_token:)
        @access_token = access_token.to_s
      end

      # review_id: Yelp review id (from Fusion /businesses/{id}/reviews).
      def respond_to_review(review_id, text)
        rid = review_id.to_s
        raise ArgumentError, 'review_id required' if rid.blank?

        url = "#{PARTNER_API_ROOT}/reviews/v1/#{rid}"
        conn = Faraday.new do |f|
          f.adapter Faraday.default_adapter
        end
        response = conn.post(url) do |req|
          req.headers['Authorization'] = "Bearer #{@access_token}"
          req.headers['Content-Type'] = 'application/json'
          req.body = {
            response_text: text.to_s,
            response_type: 'public_comment'
          }.to_json
        end
        raise "Yelp R2R HTTP #{response.status}: #{response.body}" unless response.success?

        JSON.parse(response.body)
      end
    end
  end
end
