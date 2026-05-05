class AddEmailToProxyTokens < ActiveRecord::Migration[8.1]
  def change
    add_column :proxy_tokens, :email, :string
    add_index :proxy_tokens, :email
  end
end
