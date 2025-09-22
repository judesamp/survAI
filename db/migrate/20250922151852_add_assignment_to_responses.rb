class AddAssignmentToResponses < ActiveRecord::Migration[8.0]
  def change
    add_reference :responses, :assignment, null: true, foreign_key: true
    add_column :responses, :started_at, :datetime

    add_index :responses, :started_at
  end
end
