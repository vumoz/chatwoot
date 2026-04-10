# frozen_string_literal: true

module AiResolution
  class SupportIngestService
    def initialize(account:, conversation:, source_platform: nil)
      @account = account
      @conversation = conversation
      @source_platform = source_platform
    end

    def perform
      text = extract_conversation_text
      platform = @source_platform.presence || infer_source_platform
      ReviewIngestService.new(
        account: @account,
        source_platform: platform,
        conversation_id: @conversation.id,
        source_message_id: @conversation.last_incoming_message&.id&.to_s,
        source_payload: {
          'text' => text,
          'conversation_display_id' => @conversation.display_id,
          'inbox_id' => @conversation.inbox_id,
          'customer_engine_ingest' => 'support'
        },
        occurred_at: Time.current
      ).perform
    end

    private

    def infer_source_platform
      case @conversation.inbox.channel_type
      when 'Channel::Email'
        'email'
      when 'Channel::Api'
        'api'
      else
        'chatwoot'
      end
    end

    def extract_conversation_text
      msg = @conversation.last_incoming_message
      return '' if msg.blank?

      body = msg.processed_message_content.presence || msg.content
      body.to_s.truncate(8_000)
    end
  end
end
