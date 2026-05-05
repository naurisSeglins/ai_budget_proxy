# No seed data is required.
#
# Budgets are owned by individual ProxyTokens (limit_cents, usage_cents).
# Tokens are issued on demand via:
#   - POST /tokens (self-service)
#   - Rails console: ProxyToken.create!(label: ..., email: ..., token: SecureRandom.hex(32), limit_cents: ...)
#
# A fresh database is a valid empty state — there is no global record to seed.
