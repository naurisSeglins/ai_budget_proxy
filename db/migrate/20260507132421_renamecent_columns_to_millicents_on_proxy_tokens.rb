class RenamecentColumnsToMillicentsOnProxyTokens < ActiveRecord::Migration[8.1]
  def change
    rename_column :proxy_tokens, :limit_cents, :limit_millicents
    rename_column :proxy_tokens, :usage_cents, :usage_millicents
  end
end
