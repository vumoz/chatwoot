# frozen_string_literal: true

class CreateCustomerEngineConnectors < ActiveRecord::Migration[7.1]
  def change
    create_table :customer_engine_connectors do |t|
      t.bigint :account_id, null: false
      t.string :provider, null: false
      t.string :name, null: false
      t.jsonb :settings, default: {}, null: false
      t.integer :status, default: 1, null: false
      t.datetime :last_synced_at
      t.text :last_error
      t.timestamps
    end

    add_index :customer_engine_connectors, :account_id
    add_index :customer_engine_connectors, [:account_id, :provider], name: 'idx_ce_connectors_on_account_provider'

    add_index :ai_review_signals, [:account_id, :source_platform, :source_message_id],
              unique: true,
              where: 'source_message_id IS NOT NULL',
              name: 'uniq_ai_review_signals_external_source'
  end
end
