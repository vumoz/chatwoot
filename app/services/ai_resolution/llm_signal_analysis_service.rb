# frozen_string_literal: true

module AiResolution
  class LlmSignalAnalysisService
    SYSTEM = <<~PROMPT.squish
      You classify customer reviews and support messages for routing and risk scoring.
      Return a single JSON object with keys:
      issue_category (snake_case: order_tracking, refund_request, product_quality, staff_service, faq, delivery_status, general),
      sentiment (negative, neutral, positive),
      urgency (low, medium, high, critical),
      confidence (0 to 1),
      risk_score (0 to 1; higher means more reputation or revenue risk),
      reasoning (one short sentence).
    PROMPT

    def initialize(account:, text:)
      @account = account
      @text = text.to_s.truncate(12_000)
    end

    def perform
      return nil if api_key.blank?

      Llm::Config.initialize!
      Llm::Config.with_api_key(api_key, api_base: api_base) do |context|
        chat = context.chat(model: model)
        response = chat
          .with_params(response_format: { type: 'json_object' })
          .with_instructions(SYSTEM)
          .ask(@text)
        parse_payload(response.content)
      end
    rescue StandardError => e
      Rails.logger.error("[AiResolution::LlmSignalAnalysisService] #{e.class}: #{e.message}")
      ChatwootExceptionTracker.new(e, account: @account).capture_exception if defined?(ChatwootExceptionTracker)
      nil
    end

    private

    def parse_payload(raw)
      return nil if raw.blank?

      json = JSON.parse(sanitize_json(raw))
      {
        issue_category: json['issue_category'].to_s.presence || 'general',
        sentiment: json['sentiment'].to_s,
        urgency: json['urgency'].to_s,
        confidence: json['confidence'].to_f,
        risk_score: json['risk_score'].to_f,
        reasoning: json['reasoning'].to_s,
        metadata: { 'source' => 'llm', 'reasoning' => json['reasoning'].to_s }
      }
    end

    def sanitize_json(response)
      return response if response.nil?

      response.strip.sub(/\A```(?:\w*)\s*\n?/, '').sub(/\n?\s*```\s*\z/, '').strip
    end

    def api_key
      @account.settings['customer_engine_openai_api_key'].presence ||
        InstallationConfig.find_by(name: 'CAPTAIN_OPEN_AI_API_KEY')&.value
    end

    def api_base
      endpoint = InstallationConfig.find_by(name: 'CAPTAIN_OPEN_AI_ENDPOINT')&.value.presence || 'https://api.openai.com/'
      "#{endpoint.chomp('/')}/v1"
    end

    def model
      @account.settings['customer_engine_openai_model'].presence ||
        InstallationConfig.find_by(name: 'CAPTAIN_OPEN_AI_MODEL')&.value.presence ||
        Llm::Config::DEFAULT_MODEL
    end
  end
end
