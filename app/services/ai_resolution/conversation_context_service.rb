# frozen_string_literal: true

module AiResolution
  class ConversationContextService
    def initialize(conversation:)
      @conversation = conversation
      @account = conversation.account
    end

    def as_json
      attempts = @account.ai_resolution_attempts
                           .where(conversation_id: @conversation.id)
                           .includes(ai_triage_decision: :ai_review_signal)
                           .order(created_at: :desc)
                           .limit(40)

      {
        timeline: build_timeline(attempts),
        latest_draft: extract_latest_draft(attempts),
        pending_approval: build_pending(attempts)
      }
    end

    private

    def build_timeline(attempts)
      attempts.flat_map do |a|
        d = a.ai_triage_decision
        sig = d&.ai_review_signal
        entries = []
        entries << {
          at: a.created_at,
          kind: 'attempt',
          status: a.status,
          resolution_path: d&.resolution_path,
          source_platform: sig&.source_platform,
          attempt_id: a.id,
          automated: a.automated
        }
        if a.approval_reviewed_at.present?
          entries << {
            at: a.approval_reviewed_at,
            kind: 'approval',
            attempt_id: a.id,
            reviewer_id: a.approval_reviewed_by_id,
            note: a.approval_note
          }
        end
        entries
      end.sort_by { |e| e[:at] || Time.at(0).in_time_zone }
    end

    def extract_latest_draft(attempts)
      attempts.each do |a|
        draft = a.actions_executed&.dig('draft_reply')
        return { attempt_id: a.id, text: draft } if draft.present?
      end
      nil
    end

    def build_pending(attempts)
      a = attempts.find { |x| x.requires_approval? }
      return nil if a.blank?

      {
        attempt_id: a.id,
        status: a.status,
        created_at: a.created_at,
        actions_executed: a.actions_executed
      }
    end
  end
end
