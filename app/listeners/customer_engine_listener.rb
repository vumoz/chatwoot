# frozen_string_literal: true

class CustomerEngineListener < BaseListener
  def message_created(event)
    message = event.data[:message]
    return if message.blank?
    return unless message.incoming?
    return if message.private?
    return if message.activity?
    return if performed_by_automation?(event)

    account = message.account
    return unless CustomerEngine::TenantPolicy.new(account).auto_ingest_incoming_messages?

    AiResolution::EnqueueSupportIngestJob.perform_later(message.conversation_id, message.id)
  end

  private

  def performed_by_automation?(event)
    event.data[:performed_by].present? && event.data[:performed_by].instance_of?(AutomationRule)
  end
end

CustomerEngineListener.prepend_mod_with('CustomerEngineListener')
