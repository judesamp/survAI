class CreateOrganizations < ActiveRecord::Migration[8.0]
  def change
    create_table :organizations do |t|
      t.string :name
      t.string :slug
      t.integer :plan

      t.timestamps
    end
    add_index :organizations, :slug, unique: true
  end
end
