# frozen_string_literal: true

module AiResolution
  # Runs after incoming customer messages when auto-ingest is enabled.
  # Only processes if +trigger_message_id+ is still the latest non-private incoming message
  # (drops stale jobs when multiple messages arrive in a burst).
  class EnqueueSupportIngestJob < ApplicationJob
    queue_as :low

    def perform(conversation_id, trigger_message_id)
      conversation = Conversation.find_by(id: conversation_id)
      return if conversation.blank?

      last_incoming = conversation.messages.incoming.where(private: false).order(created_at: :desc).first
      return if last_incoming.blank?
      return if last_incoming.id != trigger_message_id.to_i

      signal = SupportIngestService.new(
        account: conversation.account,
        conversation: conversation,
        source_platform: 'chatwoot'
      ).perform

      ProcessSignalJob.perform_later(signal.id)
    end
  end
end
