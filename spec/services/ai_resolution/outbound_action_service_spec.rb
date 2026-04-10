# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AiResolution::OutboundActionService do
  let(:account) { create(:account) }
  let(:signal) do
    create(:ai_review_signal, account: account, source_platform: 'yelp_fusion', source_message_id: 'y' * 22)
  end
  let(:decision) do
    create(:ai_triage_decision, account: account, ai_review_signal: signal, resolution_path: :auto_reply)
  end
  let(:attempt) do
    create(:ai_resolution_attempt, account: account, ai_triage_decision: decision, conversation: nil)
  end

  before do
    allow_any_instance_of(AiResolution::DraftReplyService).to receive(:perform).and_return('Thanks for your review.')
  end

  context 'when live Yelp public reply is enabled' do
    before do
      account.settings['customer_engine_policy'] = { 'live_yelp_public_reply' => true }
      account.save!
      create(:customer_engine_connector, account: account, provider: 'yelp_fusion', settings: {
               'api_key' => 'k',
               'business_id' => 'b',
               'partner_r2r_access_token' => 'oauth_token'
             })
    end

    it 'posts draft to Yelp Partner R2R API' do
      review_id = signal.source_message_id
      stub_request(:post, "https://partner-api.yelp.com/reviews/v1/#{review_id}")
        .to_return(status: 200, body: '{}', headers: { 'Content-Type' => 'application/json' })

      out = described_class.new(attempt: attempt, decision: decision).perform

      expect(out['yelp_public_reply']).to eq('posted')
      expect(out['draft_reply']).to be_present
    end
  end

  context 'when agent_assist path' do
    let(:decision) do
      create(:ai_triage_decision, account: account, ai_review_signal: signal, resolution_path: :agent_assist)
    end

    it 'does not post to Yelp partner API (draft-only path)' do
      account.settings['customer_engine_policy'] = { 'live_yelp_public_reply' => true }
      account.save!
      create(:customer_engine_connector, account: account)

      described_class.new(attempt: attempt, decision: decision).perform

      expect(WebMock).not_to have_requested(:post, %r{partner-api\.yelp\.com})
    end
  end
end
