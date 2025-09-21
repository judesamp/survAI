class CreateQuestions < ActiveRecord::Migration[8.0]
  def change
    create_table :questions do |t|
      t.references :survey, null: false, foreign_key: true
      t.text :question_text
      t.string :question_type
      t.boolean :required
      t.integer :position
      t.text :settings

      t.timestamps
    end
  end
end
