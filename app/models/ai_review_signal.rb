class AiReviewSignal < ApplicationRecord
  validates :account_id, presence: true
  validates :source_platform, presence: true
  validates :issue_category, presence: true
  validates :occurred_at, presence: true

  belongs_to :account
  belongs_to :conversation, optional: true

  has_many :ai_triage_decisions, dependent: :nullify

  enum sentiment: {
    negative: 0,
    neutral: 1,
    positive: 2
  }

  enum urgency: {
    low: 0,
    medium: 1,
    high: 2,
    critical: 3
  }
end

AiReviewSignal.include_mod_with('AiReviewSignal')

