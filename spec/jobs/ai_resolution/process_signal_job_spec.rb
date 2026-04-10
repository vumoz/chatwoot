# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AiResolution::ProcessSignalJob do
  let(:account) { create(:account) }
  let(:job) { described_class.new }

  describe '#triage_scope_for' do
    it 'returns review when payload marks review ingest' do
      conv = create(:conversation, account: account)
      s = build(:ai_review_signal, account: account,
                                  source_payload: { 'customer_engine_ingest' => 'review' },
                                  conversation_id: conv.id)
      expect(job.send(:triage_scope_for, s)).to eq('review')
    end

    it 'returns support when payload marks support ingest' do
      s = build(:ai_review_signal, account: account,
                                  source_payload: { 'customer_engine_ingest' => 'support' })
      expect(job.send(:triage_scope_for, s)).to eq('support')
    end
  end
end
