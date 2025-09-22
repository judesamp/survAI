class CreateAssignments < ActiveRecord::Migration[8.0]
  def change
    create_table :assignments do |t|
      t.references :survey, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.datetime :assigned_at, null: false, default: -> { 'CURRENT_TIMESTAMP' }
      t.references :assigned_by, null: false, foreign_key: { to_table: :users }
      t.boolean :completed, default: false, null: false
      t.datetime :completed_at
      t.references :response, null: true, foreign_key: true
      t.datetime :reminder_sent_at
      t.text :notes

      t.timestamps
    end

    add_index :assignments, [:survey_id, :user_id], unique: true
    add_index :assignments, :completed
  end
end
