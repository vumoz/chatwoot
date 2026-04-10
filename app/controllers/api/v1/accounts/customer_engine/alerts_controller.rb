# frozen_string_literal: true

class Api::V1::Accounts::CustomerEngine::AlertsController < Api::V1::Accounts::BaseController
  before_action :authorize_admin!

  def test
    account = Current.account
    slack_url = account.customer_engine_slack_webhook_url.presence
    email = account.customer_engine_alert_email.presence
    if slack_url.blank? && email.blank?
      render json: { error: 'Configure Slack webhook URL or alert email in Customer Engine settings' },
             status: :unprocessable_content
      return
    end

    body = I18n.t('mailers.customer_engine.test_alert.body', account_name: account.name)
    CustomerEngine::SlackWebhook.post(slack_url, body) if slack_url.present?

    CustomerEngineMailer.test_alert(account, body).deliver_later if email.present?

    render json: { sent_slack: slack_url.present?, sent_email: email.present? }
  end

  private

  def authorize_admin!
    authorize(Account, :update?)
  end
end

Api::V1::Accounts::CustomerEngine::AlertsController.prepend_mod_with(
  'Api::V1::Accounts::CustomerEngine::AlertsController'
)
