class MakeLabelNullableOnProxyTokens < ActiveRecord::Migration[8.1]
  def change
    change_column_null :proxy_tokens, :label, true
  end
end
