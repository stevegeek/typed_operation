# frozen_string_literal: true

# Single migration for the simplified demo app schema.
class CreateSchema < ActiveRecord::Migration[8.0]
  def change
    create_table :users do |t|
      t.string :email, null: false
      t.string :name
      t.string :role, null: false, default: "customer"
      t.timestamps
    end
    add_index :users, :email, unique: true

    create_table :products do |t|
      t.string :name, null: false
      t.string :pen_type, null: false
      t.decimal :price, precision: 10, scale: 2, null: false
      t.integer :stock_quantity, default: 0, null: false
      t.timestamps
    end
    add_index :products, :pen_type

    create_table :orders do |t|
      t.references :user, null: false, foreign_key: true
      t.references :product, null: true, foreign_key: true
      t.integer :quantity, default: 1, null: false
      t.decimal :total, precision: 10, scale: 2, default: 0, null: false
      t.string :status, default: "pending", null: false
      t.timestamps
    end
    add_index :orders, :status
    add_index :orders, :created_at
  end
end
