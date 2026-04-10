# frozen_string_literal: true

module CustomerEngine
  class ConnectorSyncService
    def initialize(connector)
      @connector = connector
      @account = connector.account
    end

    def perform
      raise ActiveRecord::RecordInvalid, @connector unless @connector.enabled?

      count = case @connector.provider
              when 'zendesk'
                sync_zendesk
              when 'yelp_fusion'
                sync_yelp
              when 'google_business'
                sync_google
              when 'trustpilot'
                sync_trustpilot
              when 'intercom'
                sync_intercom
              when 'shopify'
                sync_shopify
              when 'amazon_selling_partner'
                sync_amazon
              else
                0
              end

      @connector.update!(last_synced_at: Time.current, last_error: nil)
      count
    rescue StandardError => e
      @connector.update!(last_error: "#{e.class}: #{e.message}")
      raise
    end

    private

    def sync_zendesk
      s = @connector.settings
      client = Integrations::CustomerEngine::ZendeskClient.new(
        subdomain: s['subdomain'],
        email: s['email'],
        api_token: s['api_token']
      )
      tickets = client.fetch_recent_tickets(per_page: 50)
      tickets.sum { |t| ingest_zendesk_ticket(t) }
    end

    def ingest_zendesk_ticket(ticket)
      id = ticket['id'].to_s
      return 0 if id.blank?

      existing = @account.ai_review_signals.find_by(source_platform: 'zendesk', source_message_id: id)
      return 0 if existing

      body = ticket['description'].presence || ticket['subject'].presence || ''
      signal = AiResolution::ReviewIngestService.new(
        account: @account,
        source_platform: 'zendesk',
        source_message_id: id,
        source_payload: { 'text' => body, 'subject' => ticket['subject'], 'ticket' => ticket },
        occurred_at: safe_time(ticket['updated_at'])
      ).perform

      AiResolution::ProcessSignalJob.perform_later(signal.id)
      1
    end

    def sync_yelp
      s = @connector.settings
      client = Integrations::CustomerEngine::YelpClient.new(api_key: s['api_key'])
      reviews = client.fetch_reviews(s['business_id'])
      reviews.sum { |r| ingest_yelp_review(r) }
    end

    def ingest_yelp_review(review)
      id = review['id'].to_s
      return 0 if id.blank?

      existing = @account.ai_review_signals.find_by(source_platform: 'yelp_fusion', source_message_id: id)
      return 0 if existing

      text = review['text'].to_s
      rating = review['rating']
      occurred = review['time_created'].present? ? Time.zone.parse(review['time_created'].to_s) : Time.current

      signal = AiResolution::ReviewIngestService.new(
        account: @account,
        source_platform: 'yelp_fusion',
        source_message_id: id,
        source_payload: { 'text' => text, 'rating' => rating, 'review' => review },
        occurred_at: occurred
      ).perform

      AiResolution::ProcessSignalJob.perform_later(signal.id)
      1
    end

    def sync_google
      s = @connector.settings
      client = Integrations::CustomerEngine::GoogleBusinessClient.new(
        client_id: s['oauth_client_id'],
        client_secret: s['oauth_client_secret'],
        refresh_token: s['oauth_refresh_token'],
        account_resource_name: s['account_resource_name'],
        location_resource_name: s['location_resource_name']
      )
      reviews = client.fetch_reviews
      reviews.sum { |r| ingest_google_review(r) }
    end

    def ingest_google_review(review)
      name = review['reviewId'].presence || review['name'].to_s.split('/').last
      return 0 if name.blank?

      existing = @account.ai_review_signals.find_by(source_platform: 'google_business', source_message_id: name)
      return 0 if existing

      text = review['comment'].to_s
      occurred = review['createTime'].present? ? Time.zone.parse(review['createTime'].to_s) : Time.current

      signal = AiResolution::ReviewIngestService.new(
        account: @account,
        source_platform: 'google_business',
        source_message_id: name,
        source_payload: { 'text' => text, 'review' => review },
        occurred_at: occurred
      ).perform

      AiResolution::ProcessSignalJob.perform_later(signal.id)
      1
    end

    def safe_time(value)
      return Time.current if value.blank?

      Time.zone.parse(value.to_s)
    end

    def sync_trustpilot
      s = @connector.settings
      client = Integrations::CustomerEngine::TrustpilotClient.new(
        business_unit_id: s['business_unit_id'],
        oauth_access_token: s['oauth_access_token'],
        api_key: s['api_key'],
        api_secret: s['api_secret']
      )
      reviews = client.fetch_reviews
      reviews.sum { |r| ingest_trustpilot_review(r) }
    end

    def ingest_trustpilot_review(review)
      id = review['id'].presence || review.dig('review', 'id')
      id = id.to_s
      return 0 if id.blank?

      existing = @account.ai_review_signals.find_by(source_platform: 'trustpilot', source_message_id: id)
      return 0 if existing

      text = review['text'].to_s.presence || review.dig('content') || ''
      occurred = if review['createdAt'].present?
                   Time.zone.parse(review['createdAt'].to_s)
                 else
                   Time.current
                 end

      signal = AiResolution::ReviewIngestService.new(
        account: @account,
        source_platform: 'trustpilot',
        source_message_id: id,
        source_payload: { 'text' => text, 'review' => review },
        occurred_at: occurred
      ).perform

      AiResolution::ProcessSignalJob.perform_later(signal.id)
      1
    end

    def sync_intercom
      s = @connector.settings
      client = Integrations::CustomerEngine::IntercomClient.new(access_token: s['access_token'])
      conversations = client.fetch_conversations
      conversations.sum { |c| ingest_intercom_conversation(c) }
    end

    def ingest_intercom_conversation(conv)
      id = conv['id'].to_s
      return 0 if id.blank?

      existing = @account.ai_review_signals.find_by(source_platform: 'intercom', source_message_id: id)
      return 0 if existing

      text = conv['title'].to_s.presence || conv.dig('conversation_message', 'body').to_s.presence || ''
      occurred = conv['updated_at'].present? ? Time.zone.parse(conv['updated_at'].to_s) : Time.current

      signal = AiResolution::ReviewIngestService.new(
        account: @account,
        source_platform: 'intercom',
        source_message_id: id,
        source_payload: { 'text' => text, 'conversation' => conv },
        occurred_at: occurred
      ).perform

      AiResolution::ProcessSignalJob.perform_later(signal.id)
      1
    end

    def sync_shopify
      s = @connector.settings
      client = Integrations::CustomerEngine::ShopifyAdminClient.new(
        shop_domain: s['shop_domain'],
        access_token: s['access_token'],
        api_version: s['api_version'].presence || '2024-10'
      )
      products = client.fetch_products(limit: (s['product_limit'] || 50).to_i)
      products.sum { |p| ingest_shopify_product(p) }
    end

    def ingest_shopify_product(product)
      id = product['id'].to_s
      return 0 if id.blank?

      existing = @account.ai_review_signals.find_by(source_platform: 'shopify', source_message_id: id)
      return 0 if existing

      html = product['body_html'].to_s
      plain = Rails::Html::FullSanitizer.new.sanitize(html)
      text = plain.truncate(4_000)
      body = "#{product['title']}\n#{text}".strip
      occurred = product['updated_at'].present? ? Time.zone.parse(product['updated_at'].to_s) : Time.current

      signal = AiResolution::ReviewIngestService.new(
        account: @account,
        source_platform: 'shopify',
        source_message_id: id,
        source_payload: { 'text' => body, 'product' => product, 'kind' => 'product_catalog' },
        occurred_at: occurred
      ).perform

      AiResolution::ProcessSignalJob.perform_later(signal.id)
      1
    end

    def sync_amazon
      Integrations::CustomerEngine::AmazonSellingPartnerClient.new(@connector.settings).fetch_review_signals
      0
    end
  end
end
