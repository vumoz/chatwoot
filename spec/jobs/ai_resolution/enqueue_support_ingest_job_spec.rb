# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AiResolution::EnqueueSupportIngestJob do
  let(:account) { create(:account) }
  let(:conversation) { create(:conversation, account: account) }

  it 'skips when trigger message is no longer the latest incoming' do
    m1 = create(:message, account: account, conversation: conversation)
    create(:message, account: account, conversation: conversation)

    expect(AiResolution::ProcessSignalJob).not_to receive(:perform_later)

    described_class.perform_now(conversation.id, m1.id)
  end

  it 'enqueues pipeline when trigger matches latest incoming' do
    m = create(:message, account: account, conversation: conversation)

    expect(AiResolution::ProcessSignalJob).to receive(:perform_later).once

    described_class.perform_now(conversation.id, m.id)
  end
end
