class CreateSurveyInsights < ActiveRecord::Migration[8.0]
  def change
    create_table :survey_insights do |t|
      t.references :survey, null: false, foreign_key: true
      t.json :insights_data, null: false
      t.references :generated_by, null: false, foreign_key: { to_table: :users }
      t.datetime :generated_at, null: false
      t.string :analysis_version, default: "1.0"
      t.text :summary # Short summary for listing pages

      t.timestamps
    end

    add_index :survey_insights, [:survey_id, :generated_at]
  end
end
