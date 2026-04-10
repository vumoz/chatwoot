# frozen_string_literal: true

require 'faraday'

module CustomerEngine
  module SlackWebhook
    module_function

    def post(url, text)
      return if url.blank?

      Faraday.post(
        url,
        { text: text }.to_json,
        'Content-Type' => 'application/json'
      )
    rescue StandardError => e
      Rails.logger.error("[CustomerEngine::SlackWebhook] #{e.class}: #{e.message}")
      raise
    end
  end
end
