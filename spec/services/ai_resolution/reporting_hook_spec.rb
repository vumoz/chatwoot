# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AiResolution::ReportingHook do
  let(:account) { create(:account) }
  let(:signal) { create(:ai_review_signal, account: account) }
  let(:decision) do
    create(:ai_triage_decision, account: account, ai_review_signal: signal, resolution_path: :auto_reply)
  end

  it 'records ai_resolution_automated for succeeded automated attempts' do
    attempt = create(
      :ai_resolution_attempt,
      account: account,
      ai_triage_decision: decision,
      status: :succeeded,
      automated: true,
      completed_at: Time.current
    )

    expect do
      described_class.record(attempt)
    end.to change(ReportingEvent, :count).by(1)

    expect(ReportingEvent.last.name).to eq('ai_resolution_automated')
  end

  it 'records ai_resolution_agent_assist for succeeded agent assist' do
    assist_decision = create(
      :ai_triage_decision,
      account: account,
      ai_review_signal: signal,
      resolution_path: :agent_assist
    )
    attempt = create(
      :ai_resolution_attempt,
      account: account,
      ai_triage_decision: assist_decision,
      status: :succeeded,
      automated: false,
      completed_at: Time.current
    )

    expect do
      described_class.record(attempt)
    end.to change(ReportingEvent, :count).by(1)

    expect(ReportingEvent.last.name).to eq('ai_resolution_agent_assist')
  end

  it 'records ai_resolution_escalated for requires_approval' do
    attempt = create(
      :ai_resolution_attempt,
      account: account,
      ai_triage_decision: decision,
      status: :requires_approval,
      automated: false,
      completed_at: Time.current
    )

    expect do
      described_class.record(attempt)
    end.to change(ReportingEvent, :count).by(1)

    expect(ReportingEvent.last.name).to eq('ai_resolution_escalated')
  end
end
