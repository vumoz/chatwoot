# frozen_string_literal: true

module AiResolution
  class TriagePipelineService
    def initialize(signal:, decision_scope: 'review')
      @signal = signal
      @decision_scope = decision_scope.to_s
    end

    def perform
      confidence = SignalAnalysisService.new(signal: @signal).perform
      policy = CustomerEngine::TenantPolicy.new(@signal.account)
      automation_level = policy.automation_level

      path = DecisionRouterService.new(
        account: @signal.account,
        issue_category: @signal.issue_category,
        confidence_score: confidence,
        automation_level: automation_level,
        policy: policy
      ).perform

      analysis = (@signal.source_payload['analysis'] || {}).stringify_keys
      model_label, model_ver = resolve_model_labels(analysis)

      decision = AiTriageDecision.create!(
        account: @signal.account,
        conversation: @signal.conversation,
        ai_review_signal: @signal,
        decision_scope: map_scope(@decision_scope),
        resolution_path: path,
        confidence_score: confidence,
        automation_level: automation_level,
        model_name: model_label,
        model_version: model_ver,
        decided_at: Time.current,
        decision_metadata: {
          analyzer: analysis['source'] || 'heuristic',
          source: 'customer_engine'
        },
        policy_snapshot: policy.as_json
      )

      attempt = AiResolutionAttempt.create!(
        account: @signal.account,
        conversation: @signal.conversation,
        ai_triage_decision: decision,
        status: :queued,
        resolution_channel: @decision_scope,
        automated: %w[auto_reply auto_resolve].include?(path),
        started_at: Time.current,
        actions_requested: { path: path, scope: @decision_scope }
      )

      ExecuteAttemptService.new(attempt: attempt, decision: decision).perform

      { signal: @signal, decision: decision, attempt: attempt.reload }
    end

    private

    def resolve_model_labels(analysis)
      if analysis['source'] == 'llm'
        model = @signal.account.customer_engine_openai_model.presence ||
                InstallationConfig.find_by(name: 'CAPTAIN_OPEN_AI_MODEL')&.value.presence ||
                Llm::Config::DEFAULT_MODEL
        [model, '1']
      else
        ['heuristic_v1', '1']
      end
    end

    def map_scope(scope)
      case scope
      when 'support'
        :support
      when 'churn'
        :churn
      else
        :review
      end
    end
  end
end
