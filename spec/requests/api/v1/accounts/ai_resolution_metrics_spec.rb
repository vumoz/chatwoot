# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Ai resolution metrics API' do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }

  describe 'GET /api/v1/accounts/:account_id/ai_resolution/metrics' do
    it 'returns extended metrics payload' do
      get "/api/v1/accounts/#{account.id}/ai_resolution/metrics",
          headers: admin.create_new_auth_token

      expect(response).to have_http_status(:success)
      json = response.parsed_body
      expect(json).to include(
        'review_signals_count',
        'triage_decisions_count',
        'resolution_attempts_succeeded',
        'resolution_attempts_automated_succeeded',
        'resolution_attempts_agent_assist_succeeded',
        'resolution_attempts_pending_approval',
        'resolution_attempts_failed'
      )
    end
  end
end
