# frozen_string_literal: true

module AiResolution
  class HeuristicSignalAnalysisService
    PATTERNS = [
      { key: :order_tracking, regex: /\b(where\s+is\s+my|track(ing)?|shipment|order\s+status|delivery\s+status|wheres\s+my)\b/i,
        sentiment: :negative, urgency: :medium, base_confidence: 0.82 },
      { key: :faq, regex: /\b(hours?|open|close|location|phone|address|how\s+do\s+i)\b/i,
        sentiment: :neutral, urgency: :low, base_confidence: 0.7 },
      { key: :delivery_status, regex: /\b(late|delayed|never\s+arrived|missing\s+package|wrong\s+address)\b/i,
        sentiment: :negative, urgency: :high, base_confidence: 0.8 },
      { key: :refund_request, regex: /\b(refund|chargeback|money\s+back|cancel\s+order)\b/i,
        sentiment: :negative, urgency: :high, base_confidence: 0.78 },
      { key: :product_quality, regex: /\b(broken|defect|not\s+working|quality|damaged)\b/i,
        sentiment: :negative, urgency: :medium, base_confidence: 0.74 },
      { key: :staff_service, regex: /\b(rude|unprofessional|manager|staff|service)\b/i,
        sentiment: :negative, urgency: :medium, base_confidence: 0.72 }
    ].freeze

    def initialize(signal:, text:)
      @signal = signal
      @text = text.to_s
    end

    def classify
      return default_result if @text.blank?

      best = PATTERNS.map do |rule|
        match = @text.match(rule[:regex])
        next unless match

        boost = [0.08, (match[0].length / @text.length.to_f) * 0.15].min
        confidence = [0.95, rule[:base_confidence] + boost].min
        {
          issue_category: rule[:key].to_s,
          sentiment: rule[:sentiment],
          urgency: rule[:urgency],
          confidence: confidence,
          risk_score: rule[:urgency] == :high ? 0.65 : 0.35,
          metadata: { matched_pattern: rule[:key].to_s, source: 'heuristic' }
        }
      end.compact.max_by { |r| r[:confidence] }

      return default_result if best.blank?

      best
    end

    private

    def default_result
      negative = @text.match?(/\b(terrible|awful|worst|never|disgusted|angry|furious)\b/i)

      {
        issue_category: 'general',
        sentiment: negative ? :negative : :neutral,
        urgency: negative ? :medium : :low,
        confidence: negative ? 0.55 : 0.5,
        risk_score: negative ? 0.45 : 0.2,
        metadata: { matched_pattern: 'default', source: 'heuristic' }
      }
    end
  end
end
