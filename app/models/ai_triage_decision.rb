class AiTriageDecision < ApplicationRecord
  validates :account_id, presence: true
  validates :resolution_path, presence: true
  validates :decided_at, presence: true

  belongs_to :account
  belongs_to :conversation, optional: true
  belongs_to :ai_review_signal, optional: true

  has_many :ai_resolution_attempts, dependent: :restrict_with_error

  enum decision_scope: {
    support: 'support',
    review: 'review',
    churn: 'churn'
  }

  enum resolution_path: {
    auto_resolve: 'auto_resolve',
    auto_reply: 'auto_reply',
    agent_assist: 'agent_assist',
    escalate: 'escalate'
  }
end

AiTriageDecision.include_mod_with('AiTriageDecision')

