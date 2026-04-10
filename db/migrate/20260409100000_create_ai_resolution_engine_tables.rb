class CreateAiResolutionEngineTables < ActiveRecord::Migration[7.1]
  def change
    create_table :ai_review_signals do |t|
      t.bigint :account_id, null: false
      t.bigint :conversation_id
      t.string :source_platform, null: false
      t.string :source_message_id
      t.integer :sentiment, null: false, default: 1
      t.string :issue_category, null: false
      t.integer :urgency, null: false, default: 0
      t.float :risk_score, default: 0.0, null: false
      t.jsonb :source_payload, default: {}, null: false
      t.datetime :occurred_at, null: false

      t.timestamps
    end

    add_index :ai_review_signals, :account_id
    add_index :ai_review_signals, :conversation_id
    add_index :ai_review_signals, [:account_id, :source_platform, :occurred_at], name: 'idx_ai_review_signals_on_account_platform_time'
    add_index :ai_review_signals, [:account_id, :issue_category, :occurred_at], name: 'idx_ai_review_signals_on_account_issue_time'

    create_table :ai_triage_decisions do |t|
      t.bigint :account_id, null: false
      t.bigint :conversation_id
      t.bigint :ai_review_signal_id
      t.string :decision_scope, null: false, default: 'support'
      t.string :resolution_path, null: false
      t.float :confidence_score, null: false, default: 0.0
      t.integer :automation_level, null: false, default: 1
      t.string :model_name
      t.string :model_version
      t.jsonb :decision_metadata, default: {}, null: false
      t.jsonb :policy_snapshot, default: {}, null: false
      t.datetime :decided_at, null: false

      t.timestamps
    end

    add_index :ai_triage_decisions, :account_id
    add_index :ai_triage_decisions, :conversation_id
    add_index :ai_triage_decisions, :ai_review_signal_id
    add_index :ai_triage_decisions, [:account_id, :decision_scope, :decided_at], name: 'idx_ai_triage_decisions_on_scope_time'

    create_table :ai_resolution_attempts do |t|
      t.bigint :account_id, null: false
      t.bigint :conversation_id
      t.bigint :ai_triage_decision_id, null: false
      t.integer :status, null: false, default: 0
      t.string :resolution_channel
      t.boolean :automated, null: false, default: false
      t.float :customer_impact_score, default: 0.0, null: false
      t.jsonb :actions_requested, default: {}, null: false
      t.jsonb :actions_executed, default: {}, null: false
      t.text :failure_reason
      t.datetime :started_at, null: false
      t.datetime :completed_at

      t.timestamps
    end

    add_index :ai_resolution_attempts, :account_id
    add_index :ai_resolution_attempts, :conversation_id
    add_index :ai_resolution_attempts, :ai_triage_decision_id
    add_index :ai_resolution_attempts, [:account_id, :status, :created_at], name: 'idx_ai_resolution_attempts_on_status_time'
  end
end

