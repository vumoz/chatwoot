# frozen_string_literal: true

module AiResolution
  class ExecuteAttemptService
    def initialize(attempt:, decision:)
      @attempt = attempt
      @decision = decision
    end

    def perform
      @attempt.update!(status: :in_progress)

      case @decision.resolution_path
      when 'auto_reply', 'auto_resolve'
        outbound = OutboundActionService.new(attempt: @attempt, decision: @decision).perform
        complete_success(
          actions: { outcome: 'completed', path: @decision.resolution_path }.merge(stringify_outbound(outbound)),
          automated: true
        )
      when 'agent_assist'
        outbound = OutboundActionService.new(attempt: @attempt, decision: @decision).perform
        complete_success(
          actions: { outcome: 'agent_assist', path: 'dashboard' }.merge(stringify_outbound(outbound)),
          automated: false
        )
      when 'escalate'
        complete_escalation
      else
        @attempt.update!(
          status: :failed,
          completed_at: Time.current,
          failure_reason: "Unknown resolution path: #{@decision.resolution_path}"
        )
      end

      ReportingHook.record(@attempt)
      @attempt.reload
    end

    private

    def stringify_outbound(hash)
      hash.stringify_keys
    end

    def complete_success(actions:, automated:)
      @attempt.update!(
        status: :succeeded,
        completed_at: Time.current,
        actions_executed: actions,
        automated: automated
      )
    end

    def complete_escalation
      @attempt.update!(
        status: :requires_approval,
        completed_at: Time.current,
        actions_executed: { outcome: 'escalated', path: @decision.resolution_path },
        automated: false
      )
    end
  end
end
