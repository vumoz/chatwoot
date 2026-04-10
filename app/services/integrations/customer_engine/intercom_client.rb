# frozen_string_literal: true

require 'faraday'

module Integrations
  module CustomerEngine
    # Intercom REST API — list conversations (read-only sync into Customer Engine signals).
    # Ref: https://developers.intercom.com/intercom-api-reference
    class IntercomClient
      BASE = 'https://api.intercom.io'

      def initialize(access_token:)
        @access_token = access_token
      end

      def fetch_conversations(per_page: 40)
        conn = Faraday.new(url: BASE) do |f|
          f.adapter Faraday.default_adapter
        end
        response = conn.get('/conversations') do |req|
          req.headers['Authorization'] = "Bearer #{@access_token}"
          req.headers['Accept'] = 'application/json'
          req.headers['Intercom-Version'] = '2.11'
          req.params['per_page'] = per_page
        end
        raise "Intercom HTTP #{response.status}: #{response.body}" unless response.success?

        data = JSON.parse(response.body)
        Array(data['conversations'] || data['data'] || [])
      end
    end
  end
end
