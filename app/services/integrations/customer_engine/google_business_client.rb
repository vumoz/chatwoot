# frozen_string_literal: true

require 'faraday'

module Integrations
  module CustomerEngine
    class GoogleBusinessClient
      TOKEN_URL = 'https://oauth2.googleapis.com/token'
      API_ROOT = 'https://mybusiness.googleapis.com/v4'

      def initialize(client_id:, client_secret:, refresh_token:, account_resource_name:, location_resource_name:)
        @client_id = client_id
        @client_secret = client_secret
        @refresh_token = refresh_token
        a = account_resource_name.to_s.sub(%r{\A/}, '').sub(%r{/\z}, '')
        l = location_resource_name.to_s.sub(%r{\A/}, '').sub(%r{/\z}, '')
        @parent = "#{a}/#{l}"
      end

      def fetch_reviews
        url = "#{API_ROOT}/#{@parent}/reviews"
        conn = Faraday.new do |f|
          f.adapter Faraday.default_adapter
        end
        response = conn.get(url) do |req|
          req.headers['Authorization'] = "Bearer #{access_token}"
        end
        raise "Google Business HTTP #{response.status}: #{response.body}" unless response.success?

        data = JSON.parse(response.body)
        Array(data['reviews'])
      end

      # review_name: full resource name, e.g. accounts/.../locations/.../reviews/...
      def update_reply(review_name, comment)
        name = review_name.to_s.sub(%r{\A/}, '').sub(%r{/\z}, '')
        url = "#{API_ROOT}/#{name}/reply"
        conn = Faraday.new do |f|
          f.adapter Faraday.default_adapter
        end
        response = conn.put(url) do |req|
          req.headers['Authorization'] = "Bearer #{access_token}"
          req.headers['Content-Type'] = 'application/json'
          req.body = { comment: comment.to_s }.to_json
        end
        raise "Google Business reply HTTP #{response.status}: #{response.body}" unless response.success?

        JSON.parse(response.body)
      end

      def access_token
        @access_token ||= refresh_access_token!
      end

      private

      def refresh_access_token!
        conn = Faraday.new(url: TOKEN_URL) do |f|
          f.request :url_encoded
          f.adapter Faraday.default_adapter
        end
        response = conn.post do |req|
          req.body = {
            grant_type: 'refresh_token',
            refresh_token: @refresh_token,
            client_id: @client_id,
            client_secret: @client_secret
          }
        end
        raise "Google OAuth HTTP #{response.status}: #{response.body}" unless response.success?

        JSON.parse(response.body)['access_token']
      end
    end
  end
end
