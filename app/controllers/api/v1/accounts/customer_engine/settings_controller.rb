# frozen_string_literal: true

class Api::V1::Accounts::CustomerEngine::SettingsController < Api::V1::Accounts::BaseController
  before_action :authorize_admin!

  def show
    account = Current.account
    render json: {
      policy: CustomerEngine::TenantPolicy.new(account).as_json,
      slack_webhook_configured: account.customer_engine_slack_webhook_url.present?,
      slack_webhook_url_masked: mask_secret(account.customer_engine_slack_webhook_url),
      alert_email: account.customer_engine_alert_email,
      openai_api_key_masked: mask_secret(account.customer_engine_openai_api_key),
      openai_model: account.customer_engine_openai_model,
      openai_configured: account.customer_engine_openai_api_key.present? ||
        InstallationConfig.find_by(name: 'CAPTAIN_OPEN_AI_API_KEY')&.value.present?
    }
  end

  def update
    account = Current.account
    merge_customer_engine_settings(account, settings_params)
    account.save!
    render json: { message: 'ok' }, status: :ok
  end

  private

  def authorize_admin!
    authorize(Account, :update?)
  end

  def settings_params
    params.permit(
      :slack_webhook_url,
      :alert_email,
      :openai_api_key,
      :openai_model,
      policy: {}
    )
  end

  def merge_customer_engine_settings(account, p)
    if p.key?(:slack_webhook_url) && p[:slack_webhook_url].present?
      account.customer_engine_slack_webhook_url = p[:slack_webhook_url]
    end
    account.customer_engine_alert_email = p[:alert_email] if p.key?(:alert_email)
    account.customer_engine_openai_model = p[:openai_model] if p.key?(:openai_model)
    if p.key?(:openai_api_key) && p[:openai_api_key].present?
      account.customer_engine_openai_api_key = p[:openai_api_key]
    end

    return unless p[:policy].present?

    account.settings['customer_engine_policy'] = p[:policy].permit!.to_h
  end

  def mask_secret(val)
    return nil if val.blank?

    s = val.to_s
    return "****#{s.last(4)}" if s.length <= 12

    "#{s[0..15]}…****#{s.last(4)}"
  end
end

Api::V1::Accounts::CustomerEngine::SettingsController.prepend_mod_with(
  'Api::V1::Accounts::CustomerEngine::SettingsController'
)
