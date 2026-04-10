# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Integrations::CustomerEngine::YelpPartnerClient do
  describe '#respond_to_review' do
    it 'posts a public_comment response to partner-api' do
      review_id = 'a' * 22
      stub_request(:post, "https://partner-api.yelp.com/reviews/v1/#{review_id}")
        .with(
          body: {
            response_text: 'Thank you for your review.',
            response_type: 'public_comment'
          }.to_json,
          headers: { 'Authorization' => 'Bearer test_token' }
        )
        .to_return(status: 200, body: '{"status":"ok"}', headers: { 'Content-Type' => 'application/json' })

      client = described_class.new(access_token: 'test_token')
      result = client.respond_to_review(review_id, 'Thank you for your review.')

      expect(result['status']).to eq('ok')
    end

    it 'raises when review_id is blank' do
      client = described_class.new(access_token: 'x')
      expect { client.respond_to_review('', 'Hi') }.to raise_error(ArgumentError)
    end
  end
end
