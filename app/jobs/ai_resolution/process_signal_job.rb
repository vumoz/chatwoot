# frozen_string_literal: true

module AiResolution
  class ProcessSignalJob < ApplicationJob
    queue_as :low

    def perform(ai_review_signal_id)
      signal = AiReviewSignal.find_by(id: ai_review_signal_id)
      return if signal.blank?

      scope = triage_scope_for(signal)
      TriagePipelineService.new(signal: signal, decision_scope: scope).perform
    end

    private

    def triage_scope_for(signal)
      case signal.source_payload['customer_engine_ingest']
      when 'support' then 'support'
      when 'review' then 'review'
      else
        signal.conversation_id.present? ? 'support' : 'review'
      end
    end
  end
end
