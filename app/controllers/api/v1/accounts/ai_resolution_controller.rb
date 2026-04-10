# frozen_string_literal: true

class Api::V1::Accounts::AiResolutionController < Api::V1::Accounts::BaseController
  before_action :authorize_account_for_read!, only: [:metrics, :review_signals]
  before_action :authorize_account_for_write!, only: [:ingest_review, :ingest_support]

  def ingest_review
    signal = AiResolution::ReviewIngestService.new(
      account: Current.account,
      source_platform: params.require(:source_platform),
      source_payload: params.require(:source_payload).permit!.to_h,
      source_message_id: params[:source_message_id],
      conversation_id: resolve_optional_conversation_id,
      occurred_at: parse_occurred_at(params[:occurred_at])
    ).perform

    AiResolution::ProcessSignalJob.perform_later(signal.id)

    render json: { ai_review_signal_id: signal.id, status: 'queued' }, status: :accepted
  end

  def ingest_support
    conversation = Current.account.conversations.find(params.require(:conversation_id))

    signal = AiResolution::SupportIngestService.new(
      account: Current.account,
      conversation: conversation,
      source_platform: params[:source_platform].presence || 'chatwoot'
    ).perform

    AiResolution::ProcessSignalJob.perform_later(signal.id)

    render json: { ai_review_signal_id: signal.id, status: 'queued' }, status: :accepted
  end

  def metrics
    account = Current.account
    attempts = account.ai_resolution_attempts
    agent_assist_succeeded = attempts.succeeded
                             .joins(:ai_triage_decision)
                             .merge(AiTriageDecision.where(resolution_path: :agent_assist))
                             .count

    render json: {
      review_signals_count: account.ai_review_signals.count,
      triage_decisions_count: account.ai_triage_decisions.count,
      resolution_attempts_succeeded: attempts.succeeded.count,
      resolution_attempts_automated_succeeded: attempts.succeeded.where(automated: true).count,
      resolution_attempts_agent_assist_succeeded: agent_assist_succeeded,
      resolution_attempts_pending_approval: attempts.requires_approval.count,
      resolution_attempts_failed: attempts.failed.count
    }
  end

  def review_signals
    signals = Current.account.ai_review_signals
                      .includes(:conversation)
                      .order(occurred_at: :desc)
                      .limit(permitted_limit)
    render json: {
      data: signals.map { |s| serialize_review_signal(s) }
    }
  end

  private

  def resolve_optional_conversation_id
    cid = params[:conversation_id]
    return if cid.blank?

    Current.account.conversations.find(cid).id
  end

  def parse_occurred_at(raw)
    return if raw.blank?

    Time.zone.parse(raw.to_s)
  end

  def permitted_limit
    [[params.fetch(:limit, 50).to_i, 1].max, 200].min
  end

  def serialize_review_signal(signal)
    conv = signal.conversation
    base = signal.as_json(
      only: %i[id source_platform issue_category sentiment urgency risk_score occurred_at conversation_id]
    )
    base.merge(
      'conversation_display_id' => conv&.display_id,
      'conversation_url' => conv ? "/app/accounts/#{signal.account_id}/conversations/#{conv.id}" : nil
    )
  end

  def authorize_account_for_read!
    authorize(Account, :show?)
  end

  def authorize_account_for_write!
    authorize(Account, :update?)
  end
end

Api::V1::Accounts::AiResolutionController.prepend_mod_with('Api::V1::Accounts::AiResolutionController')
