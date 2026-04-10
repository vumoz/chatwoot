# frozen_string_literal: true

module AiResolution
  class ChatwootPrivateNoteService
    def initialize(account:, attempt:, conversation:, draft_text:)
      @account = account
      @attempt = attempt
      @conversation = conversation
      @draft_text = draft_text.to_s
    end

    def perform
      return nil if @draft_text.blank?
      return nil if @conversation.blank?
      return nil if already_posted?

      user = @account.administrators.first || @account.users.order(:id).first
      return nil if user.blank?

      body = I18n.t(
        'customer_engine.chatwoot_private_note.body',
        draft: @draft_text
      )
      params = ActionController::Parameters.new(
        content: body,
        private: true,
        message_type: 'outgoing',
        content_attributes: {
          'customer_engine_attempt_id' => @attempt.id,
          'customer_engine' => true
        }
      ).permit!

      Messages::MessageBuilder.new(user, @conversation, params).perform
    end

    private

    def already_posted?
      @conversation.messages.where(private: true).where(
        "content_attributes::jsonb ->> 'customer_engine_attempt_id' = ?",
        @attempt.id.to_s
      ).exists?
    end
  end
end
