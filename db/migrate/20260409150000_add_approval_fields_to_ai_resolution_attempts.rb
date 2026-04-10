# frozen_string_literal: true

class AddApprovalFieldsToAiResolutionAttempts < ActiveRecord::Migration[7.1]
  def change
    add_reference :ai_resolution_attempts, :approval_reviewed_by, foreign_key: { to_table: :users }, index: true
    add_column :ai_resolution_attempts, :approval_reviewed_at, :datetime
    add_column :ai_resolution_attempts, :approval_note, :text
  end
end
