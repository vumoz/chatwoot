# frozen_string_literal: true

class Api::V1::Accounts::CustomerEngine::ConversationContextController < Api::V1::Accounts::BaseController
  before_action :conversation

  def show
    authorize @conversation, :show?

    render json: AiResolution::ConversationContextService.new(conversation: @conversation).as_json
  end

  private

  def conversation
    @conversation = Current.account.conversations.find(params.require(:conversation_id))
  end
end

Api::V1::Accounts::CustomerEngine::ConversationContextController.prepend_mod_with(
  'Api::V1::Accounts::CustomerEngine::ConversationContextController'
)
