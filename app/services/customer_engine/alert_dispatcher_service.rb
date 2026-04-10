# frozen_string_literal: true

module CustomerEngine
  class AlertDispatcherService
    def initialize(signal)
      @signal = signal
      @account = signal.account
      @policy = TenantPolicy.new(@account)
    end

    def dispatch_if_needed
      return if @signal.risk_score.to_f < @policy.risk_alert_threshold

      body = format_body
      slack_url = @account.customer_engine_slack_webhook_url.presence
      SlackWebhook.post(slack_url, body) if slack_url.present?

      email = @account.customer_engine_alert_email.presence
      CustomerEngineMailer.risk_alert(@account, @signal, body).deliver_later if email.present?
    end

    private

    def format_body
      <<~TXT.squish
        Customer Engine risk alert for #{@account.name} (##{@account.id}):
        platform=#{@signal.source_platform}, category=#{@signal.issue_category},
        risk_score=#{@signal.risk_score.round(3)}, urgency=#{@signal.urgency},
        sentiment=#{@signal.sentiment}. Signal id=#{@signal.id}.
      TXT
    end
  end
end
