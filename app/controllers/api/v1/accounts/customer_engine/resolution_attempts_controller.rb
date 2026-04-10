# frozen_string_literal: true

class Api::V1::Accounts::CustomerEngine::ResolutionAttemptsController < Api::V1::Accounts::BaseController
  RESULTS_PER_PAGE = 25

  before_action :authorize_admin!
  before_action :set_current_page, only: [:index]

  def index
    attempts = Current.account.ai_resolution_attempts
                      .includes(:conversation, ai_triage_decision: :ai_review_signal)
                      .order(created_at: :desc)
                      .page(@current_page)
                      .per(RESULTS_PER_PAGE)

    render json: {
      data: attempts.map { |a| serialize_attempt(a) },
      meta: {
        current_page: attempts.current_page,
        total_pages: attempts.total_pages,
        total_count: attempts.total_count
      }
    }
  end

  private

  def authorize_admin!
    authorize(Account, :update?)
  end

  def set_current_page
    @current_page = params[:page] || 1
  end

  def serialize_attempt(attempt)
    decision = attempt.ai_triage_decision
    signal = decision&.ai_review_signal
    exec = attempt.actions_executed || {}
    draft = exec['draft_reply']
    conv = attempt.conversation
    account_id = attempt.account_id

    {
      id: attempt.id,
      status: attempt.status,
      automated: attempt.automated,
      resolution_path: decision&.resolution_path,
      source_platform: signal&.source_platform,
      ai_review_signal_id: signal&.id,
      conversation_id: attempt.conversation_id,
      conversation_display_id: conv&.display_id,
      conversation_url: conversation_dashboard_path(account_id, conv),
      actions_executed: attempt.actions_executed,
      draft_reply_preview: draft.present? ? draft.to_s.truncate(200) : nil,
      failure_reason: attempt.failure_reason,
      created_at: attempt.created_at,
      completed_at: attempt.completed_at
    }
  end

  def conversation_dashboard_path(account_id, conversation)
    return if conversation.blank?

    "/app/accounts/#{account_id}/conversations/#{conversation.id}"
  end
end

Api::V1::Accounts::CustomerEngine::ResolutionAttemptsController.prepend_mod_with(
  'Api::V1::Accounts::CustomerEngine::ResolutionAttemptsController'
)
