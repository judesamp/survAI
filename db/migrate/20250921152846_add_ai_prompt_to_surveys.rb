class AddAiPromptToSurveys < ActiveRecord::Migration[8.0]
  def change
    add_column :surveys, :ai_prompt, :text
  end
end
