class CreateSurveys < ActiveRecord::Migration[8.0]
  def change
    create_table :surveys do |t|
      t.string :title, null: false
      t.text :description
      t.string :slug
      t.integer :status, default: 0
      t.integer :visibility, default: 0
      t.references :organization, null: false, foreign_key: true
      t.references :created_by, null: false, foreign_key: { to_table: :users }
      t.datetime :starts_at
      t.datetime :ends_at
      t.integer :response_limit

      t.timestamps
    end
    add_index :surveys, :slug, unique: true
  end
end
