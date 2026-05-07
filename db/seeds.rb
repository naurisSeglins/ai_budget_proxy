# No seed data is required.
#
# Budgets are owned by individual ProxyTokens (limit_millicents, usage_millicents).
# 1 milli-cent = 1/1000 cent = 1/100_000 dollar.
# Tokens are issued on demand via:
#   - POST /tokens (self-service, limit param in dollars)
#   - Rails console: ProxyToken.create!(label: ..., email: ..., token: SecureRandom.hex(32), limit_millicents: 1_000_000) # $10
#
# A fresh database is a valid empty state — there is no global record to seed.
