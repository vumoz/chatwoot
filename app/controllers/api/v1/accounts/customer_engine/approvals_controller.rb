# frozen_string_literal: true

class Api::V1::Accounts::CustomerEngine::ApprovalsController < Api::V1::Accounts::BaseController
  before_action :authorize_administrator!
  before_action :attempt

  def approve
    AiResolution::ApprovalDecisionService.new(attempt: @attempt, user: Current.user).approve!(
      note: params[:note]
    )
    render json: { ok: true, attempt_id: @attempt.id }
  end

  def reject
    AiResolution::ApprovalDecisionService.new(attempt: @attempt, user: Current.user).reject!(
      reason: params.require(:reason)
    )
    render json: { ok: true, attempt_id: @attempt.id }
  end

  private

  def authorize_administrator!
    authorize Account, :update?
  end

  def attempt
    @attempt = Current.account.ai_resolution_attempts.find(params.require(:id))
  end
end

Api::V1::Accounts::CustomerEngine::ApprovalsController.prepend_mod_with(
  'Api::V1::Accounts::CustomerEngine::ApprovalsController'
)
