# frozen_string_literal: true

module AiResolution
  class SignalAnalysisService
    def initialize(signal:)
      @signal = signal
    end

    def perform
      text = extract_text(@signal.source_payload)
      llm = LlmSignalAnalysisService.new(account: @signal.account, text: text).perform
      result = llm.present? ? map_llm_result(llm) : HeuristicSignalAnalysisService.new(signal: @signal, text: text).classify

      analysis = (result[:metadata] || {}).stringify_keys.merge('confidence' => result[:confidence])

      @signal.update!(
        issue_category: result[:issue_category],
        sentiment: result[:sentiment],
        urgency: result[:urgency],
        risk_score: result[:risk_score],
        source_payload: @signal.source_payload.merge('analysis' => analysis)
      )

      CustomerEngine::AlertDispatcherService.new(@signal.reload).dispatch_if_needed

      result[:confidence]
    end

    private

    def extract_text(payload)
      payload = payload.deep_stringify_keys
      payload['text'].presence ||
        payload['body'].presence ||
        payload['content'].presence ||
        payload.dig('review', 'text').presence ||
        ''
    end

    def map_llm_result(llm)
      {
        issue_category: llm[:issue_category],
        sentiment: map_sentiment(llm[:sentiment]),
        urgency: map_urgency(llm[:urgency]),
        confidence: llm[:confidence].to_f.clamp(0.0, 1.0),
        risk_score: llm[:risk_score].to_f.clamp(0.0, 1.0),
        metadata: (llm[:metadata] || {}).merge('source' => 'llm')
      }
    end

    def map_sentiment(raw)
      case raw.to_s.downcase
      when 'positive' then :positive
      when 'negative' then :negative
      else :neutral
      end
    end

    def map_urgency(raw)
      case raw.to_s.downcase
      when 'critical' then :critical
      when 'high' then :high
      when 'medium' then :medium
      else :low
      end
    end
  end
end
