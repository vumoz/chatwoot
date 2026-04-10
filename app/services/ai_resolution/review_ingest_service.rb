# frozen_string_literal: true

module AiResolution
  class ReviewIngestService
    def initialize(account:, source_platform:, source_payload:, conversation_id: nil, source_message_id: nil, occurred_at: nil)
      @account = account
      @source_platform = source_platform
      @source_payload = source_payload.deep_stringify_keys
      @conversation_id = conversation_id
      @source_message_id = source_message_id
      @occurred_at = occurred_at
    end

    def perform
      payload = @source_payload.merge('customer_engine_ingest' => 'review')

      AiReviewSignal.create!(
        account: @account,
        conversation_id: @conversation_id,
        source_platform: @source_platform,
        source_message_id: @source_message_id,
        sentiment: :neutral,
        issue_category: 'unclassified',
        urgency: :low,
        risk_score: 0.0,
        source_payload: payload,
        occurred_at: @occurred_at || Time.current
      )
    end
  end
end
