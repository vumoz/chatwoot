# frozen_string_literal: true

module AiResolution
  module ReportingHook
    extend self

    def record(attempt)
      case attempt.status.to_sym
      when :succeeded
        if attempt.automated?
          create_event('ai_resolution_automated', attempt)
        elsif attempt.ai_triage_decision&.agent_assist?
          create_event('ai_resolution_agent_assist', attempt)
        end
      when :requires_approval
        create_event('ai_resolution_escalated', attempt)
      when :failed
        create_event('ai_resolution_failed', attempt)
      end
    end

    private

    def create_event(name, attempt)
      ReportingEvent.create!(
        account_id: attempt.account_id,
        conversation_id: attempt.conversation_id,
        name: name,
        value: 1.0,
        inbox_id: attempt.conversation&.inbox_id
      )
    end
  end
end
