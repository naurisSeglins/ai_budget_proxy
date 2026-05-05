class CreateProxyTokens < ActiveRecord::Migration[8.1]
  def change
    create_table :proxy_tokens do |t|
      t.string :token, null: false
      t.string :label, null: false
      t.boolean :revoked, null: false, default: false

      t.timestamps
    end

    add_index :proxy_tokens, :token, unique: true
  end
end
