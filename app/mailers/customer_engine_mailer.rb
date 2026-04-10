# frozen_string_literal: true

class CustomerEngineMailer < ApplicationMailer
  def risk_alert(account, signal, body_text)
    @account = account
    @signal = signal
    @body_text = body_text

    mail(
      to: account.customer_engine_alert_email,
      subject: I18n.t('mailers.customer_engine.risk_alert.subject', account_name: account.name)
    )
  end

  def test_alert(account, body_text)
    @account = account
    @body_text = body_text

    mail(
      to: account.customer_engine_alert_email,
      subject: I18n.t('mailers.customer_engine.test_alert.subject', account_name: account.name)
    )
  end
end
