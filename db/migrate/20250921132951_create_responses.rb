class CreateResponses < ActiveRecord::Migration[8.0]
  def change
    create_table :responses do |t|
      t.references :survey, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.string :session_id
      t.string :ip_address
      t.string :user_agent
      t.datetime :completed_at

      t.timestamps
    end
  end
end
