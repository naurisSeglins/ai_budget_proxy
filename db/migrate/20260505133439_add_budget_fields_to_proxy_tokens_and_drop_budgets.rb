class AddBudgetFieldsToProxyTokensAndDropBudgets < ActiveRecord::Migration[8.1]
  def change
    add_column :proxy_tokens, :limit_cents, :integer, null: false, default: 0
    add_column :proxy_tokens, :usage_cents, :integer, null: false, default: 0

    drop_table :budgets do |t|
      t.integer :limit_cents, null: false
      t.integer :usage_cents, null: false, default: 0
      t.timestamps
    end
  end
end
