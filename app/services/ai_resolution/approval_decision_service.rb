# frozen_string_literal: true

module AiResolution
  class ApprovalDecisionService
    def initialize(attempt:, user:)
      @attempt = attempt
      @user = user
    end

    def approve!(note: nil)
      raise ActiveRecord::RecordInvalid, @attempt unless @attempt.requires_approval?

      @attempt.update!(
        status: :succeeded,
        completed_at: Time.current,
        approval_reviewed_by: @user,
        approval_reviewed_at: Time.current,
        approval_note: note,
        actions_executed: (@attempt.actions_executed || {}).merge(
          'approval_outcome' => 'approved',
          'approval_reviewed_at' => Time.current.iso8601
        )
      )
      @attempt
    end

    def reject!(reason:)
      raise ActiveRecord::RecordInvalid, @attempt unless @attempt.requires_approval?

      @attempt.update!(
        status: :failed,
        completed_at: Time.current,
        failure_reason: reason.to_s,
        approval_reviewed_by: @user,
        approval_reviewed_at: Time.current,
        approval_note: reason,
        actions_executed: (@attempt.actions_executed || {}).merge('approval_outcome' => 'rejected')
      )
      @attempt
    end
  end
end

AiResolution::ApprovalDecisionService.prepend_mod_with('AiResolution::ApprovalDecisionService')
