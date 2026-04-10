# frozen_string_literal: true

require 'base64'
require 'faraday'

module Integrations
  module CustomerEngine
    class ZendeskClient
      def initialize(subdomain:, email:, api_token:)
        @subdomain = subdomain.to_s.sub(%r{\Ahttps?://}, '').sub(%r{\.zendesk\.com\z}i, '')
        @email = email
        @api_token = api_token
        @base = "https://#{@subdomain}.zendesk.com/api/v2"
        @auth_header = "Basic #{Base64.strict_encode64("#{@email}/token:#{@api_token}")}"
      end

      def fetch_recent_tickets(per_page: 50)
        conn = Faraday.new(url: @base) do |f|
          f.adapter Faraday.default_adapter
        end
        response = conn.get('/tickets.json') do |req|
          req.headers['Authorization'] = @auth_header
          req.params['sort_by'] = 'updated_at'
          req.params['sort_order'] = 'desc'
          req.params['per_page'] = per_page
        end
        raise "Zendesk HTTP #{response.status}: #{response.body}" unless response.success?

        data = JSON.parse(response.body)
        Array(data['tickets'])
      end

      def fetch_ticket(id)
        conn = Faraday.new(url: @base) do |f|
          f.adapter Faraday.default_adapter
        end
        response = conn.get("/tickets/#{id}.json") do |req|
          req.headers['Authorization'] = @auth_header
        end
        raise "Zendesk HTTP #{response.status}: #{response.body}" unless response.success?

        JSON.parse(response.body)['ticket']
      end

      def add_public_comment(ticket_id, body)
        conn = Faraday.new(url: @base) do |f|
          f.adapter Faraday.default_adapter
        end
        payload = { ticket: { comment: { body: body, public: true } } }
        response = conn.put("/tickets/#{ticket_id}.json") do |req|
          req.headers['Authorization'] = @auth_header
          req.headers['Content-Type'] = 'application/json'
          req.body = payload.to_json
        end
        raise "Zendesk HTTP #{response.status}: #{response.body}" unless response.success?

        JSON.parse(response.body)['ticket']
      end
    end
  end
end
