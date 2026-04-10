# frozen_string_literal: true

module AiResolution
  class DraftReplyService
    SYSTEM = <<~PROMPT.squish
      You write concise, empathetic, professional replies to customers (support tickets and public reviews).
      Match a neutral-to-warm brand tone. Do not invent order numbers or refunds; stay generic if details are missing.
      Return a single JSON object with key reply_text (string, the full message to send).
    PROMPT

    def initialize(account:, signal:)
      @account = account
      @signal = signal
    end

    def perform
      context = build_context
      return nil if context.blank?
      return nil if api_key.blank?

      Llm::Config.initialize!
      Llm::Config.with_api_key(api_key, api_base: api_base) do |context_chat|
        chat = context_chat.chat(model: model)
        response = chat
          .with_params(response_format: { type: 'json_object' })
          .with_instructions(SYSTEM)
          .ask(context)
        json = JSON.parse(sanitize_json(response.content))
        json['reply_text'].to_s.presence
      end
    rescue StandardError => e
      Rails.logger.error("[AiResolution::DraftReplyService] #{e.class}: #{e.message}")
      ChatwootExceptionTracker.new(e, account: @account).capture_exception if defined?(ChatwootExceptionTracker)
      nil
    end

    private

    def build_context
      p = @signal.source_payload.deep_stringify_keys
      parts = []
      parts << "Platform: #{@signal.source_platform}"
      parts << "Issue category: #{@signal.issue_category}"
      parts << "Customer text: #{p['text'].presence || p['body'].presence || p.dig('ticket', 'description')}"
      parts.join("\n").truncate(14_000)
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
