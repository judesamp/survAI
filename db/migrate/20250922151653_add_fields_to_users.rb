class AddFieldsToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :department, :string
    add_column :users, :hire_date, :date
    add_column :users, :status, :integer, default: 0, null: false
    add_column :users, :last_survey_response_at, :datetime

    add_index :users, :department
    add_index :users, :status
  end
end
