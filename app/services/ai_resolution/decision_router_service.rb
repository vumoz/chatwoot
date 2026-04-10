# frozen_string_literal: true

module AiResolution
  class DecisionRouterService
    LOW_RISK_ISSUES = %w[order_tracking faq delivery_status].freeze
    MEDIUM_RISK_ISSUES = %w[product_quality staff_service].freeze

    def initialize(account:, issue_category:, confidence_score:, automation_level: 1, policy: nil)
      @account = account
      @issue_category = issue_category.to_s
      @confidence_score = confidence_score.to_f
      @automation_level = automation_level.to_i
      @policy = policy || CustomerEngine::TenantPolicy.new(account)
    end

    def perform
      return 'escalate' unless @policy.allows_issue?(@issue_category)
      return 'escalate' if @confidence_score < 0.45
      return 'agent_assist' if @automation_level <= 1

      proposed = if low_risk_auto_reply?
                   'auto_reply'
                 elsif medium_risk_requires_review?
                   'agent_assist'
                 else
                   'escalate'
                 end

      return proposed unless automated_path?(proposed)

      return 'agent_assist' if @confidence_score < @policy.min_confidence_for_auto
      return 'agent_assist' unless @policy.rate_limit_allows_auto?

      proposed
    end

    private

    def automated_path?(path)
      %w[auto_reply auto_resolve].include?(path)
    end

    def low_risk_auto_reply?
      LOW_RISK_ISSUES.include?(@issue_category) && @confidence_score >= 0.75
    end

    def medium_risk_requires_review?
      MEDIUM_RISK_ISSUES.include?(@issue_category) && @confidence_score >= 0.65
    end
  end
end
