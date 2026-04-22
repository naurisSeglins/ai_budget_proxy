class CreateBudgets < ActiveRecord::Migration[8.1]
  def change
    create_table :budgets do |t|
      t.integer :limit_cents, null: false
      t.integer :usage_cents, null: false, default: 0

      t.timestamps
    end
  end
end
