class CreateUsers < ActiveRecord::Migration[8.0]
  def change
    create_table :users do |t|
      t.string :email_address, null: false
      t.string :password_digest, null: true  # Optional for prototype
      t.string :first_name
      t.string :last_name
      t.integer :role, default: 0
      t.references :organization, foreign_key: true

      t.timestamps
    end
    add_index :users, :email_address, unique: true
  end
end
