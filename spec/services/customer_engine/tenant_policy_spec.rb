# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CustomerEngine::TenantPolicy do
  let(:account) { create(:account) }

  it 'defaults live_yelp_public_reply to false' do
    expect(described_class.new(account).live_yelp_public_reply?).to be(false)
  end

  it 'reads live_yelp_public_reply from account settings' do
    account.settings['customer_engine_policy'] = { 'live_yelp_public_reply' => true }
    account.save!
    expect(described_class.new(account).live_yelp_public_reply?).to be(true)
  end
end
