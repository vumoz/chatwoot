# frozen_string_literal: true

FactoryBot.define do
  factory :ai_review_signal do
    account
    source_platform { 'chatwoot' }
    source_message_id { SecureRandom.hex(8) }
    issue_category { 'faq' }
    occurred_at { Time.current }
    source_payload { { 'customer_engine_ingest' => 'review', 'text' => 'Hello' } }
  end

  factory :ai_triage_decision do
    account
    ai_review_signal { association :ai_review_signal, account: account }
    decision_scope { 'review' }
    resolution_path { 'auto_reply' }
    confidence_score { 0.85 }
    automation_level { 3 }
    decided_at { Time.current }
    decision_metadata { {} }
    policy_snapshot { {} }
  end

  factory :ai_resolution_attempt do
    account
    ai_triage_decision { association :ai_triage_decision, account: account }
    status { :queued }
    started_at { Time.current }
    resolution_channel { 'review' }
    automated { true }
  end

  factory :customer_engine_connector, class: 'CustomerEngine::Connector' do
    account
    sequence(:name) { |n| "CE connector #{n}" }
    provider { 'yelp_fusion' }
    status { :enabled }
    settings do
      {
        'api_key' => 'yelp_api_key',
        'business_id' => 'business-id',
        'partner_r2r_access_token' => 'r2r_test_token'
      }
    end
  end
end
