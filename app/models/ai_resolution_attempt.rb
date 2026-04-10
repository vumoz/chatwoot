class AiResolutionAttempt < ApplicationRecord
  validates :account_id, presence: true
  validates :ai_triage_decision_id, presence: true
  validates :started_at, presence: true

  belongs_to :account
  belongs_to :conversation, optional: true
  belongs_to :ai_triage_decision
  belongs_to :approval_reviewed_by, class_name: 'User', optional: true

  enum status: {
    queued: 0,
    in_progress: 1,
    succeeded: 2,
    failed: 3,
    requires_approval: 4
  }
end

AiResolutionAttempt.include_mod_with('AiResolutionAttempt')

