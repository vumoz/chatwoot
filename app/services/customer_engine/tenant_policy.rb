# frozen_string_literal: true

module CustomerEngine
  class TenantPolicy
    DEFAULTS = {
      'automation_level' => 2,
      'allowed_issue_categories' => nil,
      'blocked_issue_categories' => [],
      'max_auto_actions_per_hour' => 500,
      'min_confidence_for_auto' => 0.72,
      'risk_alert_threshold' => 0.55,
      'generate_draft_reply' => true,
      'live_zendesk_public_comment' => false,
      'post_draft_as_private_note' => true,
      'live_google_review_reply' => false,
      'live_yelp_public_reply' => false,
      'auto_ingest_incoming_messages' => false
    }.freeze

    def initialize(account)
      @account = account
      @raw = (account.settings['customer_engine_policy'] || {}).deep_stringify_keys
    end

    def automation_level
      v = @raw['automation_level'].presence || account.customer_engine_automation_level
      (v.to_i).clamp(1, 5)
    end

    def allows_issue?(category)
      cat = category.to_s
      return false if blocked_issue_categories.include?(cat)

      allowed = allowed_issue_categories
      return false if allowed == []

      return true if allowed.nil?

      allowed.include?(cat)
    end

    def blocked_issue_categories
      Array(@raw['blocked_issue_categories']).map(&:to_s)
    end

    def allowed_issue_categories
      raw = @raw['allowed_issue_categories']
      return nil if raw.nil?
      return [] if raw == []

      Array(raw).map(&:to_s).presence
    end

    def max_auto_actions_per_hour
      (@raw['max_auto_actions_per_hour'].presence || DEFAULTS['max_auto_actions_per_hour']).to_i
    end

    def min_confidence_for_auto
      (@raw['min_confidence_for_auto'].presence || DEFAULTS['min_confidence_for_auto']).to_f
    end

    def risk_alert_threshold
      (@raw['risk_alert_threshold'].presence || DEFAULTS['risk_alert_threshold']).to_f
    end

    def rate_limit_allows_auto?
      max = max_auto_actions_per_hour
      return true if max <= 0

      count = @account.ai_resolution_attempts.where(automated: true).where('created_at > ?', 1.hour.ago).count
      count < max
    end

    def generate_draft_reply?
      v = @raw['generate_draft_reply']
      return DEFAULTS['generate_draft_reply'] if v.nil?

      ActiveModel::Type::Boolean.new.cast(v)
    end

    def live_zendesk_public_comment?
      ActiveModel::Type::Boolean.new.cast(@raw['live_zendesk_public_comment'])
    end

    def post_draft_as_private_note?
      v = @raw['post_draft_as_private_note']
      return DEFAULTS['post_draft_as_private_note'] if v.nil?

      ActiveModel::Type::Boolean.new.cast(v)
    end

    def live_google_review_reply?
      ActiveModel::Type::Boolean.new.cast(@raw['live_google_review_reply'])
    end

    def auto_ingest_incoming_messages?
      ActiveModel::Type::Boolean.new.cast(@raw['auto_ingest_incoming_messages'])
    end

    def live_yelp_public_reply?
      ActiveModel::Type::Boolean.new.cast(@raw['live_yelp_public_reply'])
    end

    def as_json(*)
      DEFAULTS.merge(@raw).merge(
        'automation_level' => automation_level,
        'blocked_issue_categories' => blocked_issue_categories,
        'allowed_issue_categories' => allowed_issue_categories,
        'max_auto_actions_per_hour' => max_auto_actions_per_hour,
        'min_confidence_for_auto' => min_confidence_for_auto,
        'risk_alert_threshold' => risk_alert_threshold,
        'generate_draft_reply' => generate_draft_reply?,
        'live_zendesk_public_comment' => live_zendesk_public_comment?,
        'post_draft_as_private_note' => post_draft_as_private_note?,
        'live_google_review_reply' => live_google_review_reply?,
        'live_yelp_public_reply' => live_yelp_public_reply?,
        'auto_ingest_incoming_messages' => auto_ingest_incoming_messages?
      )
    end

    attr_reader :account
  end
end
