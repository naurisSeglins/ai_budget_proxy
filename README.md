# ai_budget proxy

A stateless HTTP proxy that sits between your app and OpenAI and enforces a hard spend cap. When the cap is hit, requests stop — no runaway bills from a loop gone wrong or a forgotten test script. Your OpenAI key never touches the proxy server; you supply it on each request and it is forwarded directly.

---

## How it works

```
your app
  │  Authorization: Bearer <proxy-token>
  │  X-Provider-Authorization: Bearer <your-openai-key>
  ▼
ai_budget proxy  ──── enforces spend cap ────► OpenAI API
  │                   debits usage_millicents
  ▼
PostgreSQL (proxy tokens, spend tracking)
```

The proxy authenticates your app via a proxy token, checks the token's remaining budget, forwards the request to OpenAI with your credential in the standard `Authorization` header, and debits the cost after a successful response. If the budget is exhausted the request is refused before any upstream call is made.

**What is not in scope for this release:** streaming responses (SSE), a self-service dashboard, and multi-user token management UI. See [Roadmap](#roadmap).

---

## Status

Public status page (monitored every 1 minute from multiple locations):
**https://stats.uptimerobot.com/iksO5GXjsP**

Production endpoint: `https://ai-budget-proxy.fly.dev`

---

## Latency

Measured 2026-05-11 against `https://ai-budget-proxy.fly.dev` (Fly.io `ams`), `gpt-4o-mini`, single short message, 1 worker, 194 successful requests:

```
Total round-trip (proxy + OpenAI)
  p50  : 919 ms
  p95  : 1563 ms
  min  : 736 ms
  max  : 4350 ms
  mean : 1014 ms
```

The `openai-processing-ms` header is not present in OpenAI responses, so proxy overhead cannot be isolated from model latency. The bulk of round-trip time is OpenAI inference.

---

## Prerequisites

- Ruby 3.4.8
- PostgreSQL 14+

---

## Setup

```sh
bundle install
bin/rails db:setup    # creates the database and runs all migrations
                      # seeds.rb is a no-op — tokens are created on demand
```

Start the server:

```sh
bin/rails server
```

Confirm it is running:

```sh
curl -s http://localhost:3000/up
```

---

## Creating a proxy token

Tokens are managed from the Rails console or via the `POST /tokens` endpoint.

**Via Rails console:**

```ruby
token = ProxyToken.create!(
  label:            "my-app",
  email:            "owner@example.com",
  token:            SecureRandom.hex(32),
  limit_millicents: 10 * 100_000  # replace 10 with the dollar cap you want
)
puts token.token   # share this value with your caller
```

**Via HTTP:**

```sh
curl -s -X POST https://ai-budget-proxy.fly.dev/tokens \
  -H "Content-Type: application/json" \
  -d '{"email":"owner@example.com","limit":10,"label":"my-app"}' \
  | jq
```

---

## Making a request

Two headers are required on every call to `POST /proxy`:

| Header | Value |
|---|---|
| `Authorization` | `Bearer <proxy-token>` — identifies your app to the proxy |
| `X-Provider-Authorization` | `Bearer <your-openai-key>` — forwarded to OpenAI verbatim |

```sh
curl -s -X POST https://ai-budget-proxy.fly.dev/proxy \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer <proxy-token>" \
  -H "X-Provider-Authorization: Bearer sk-..." \
  -d '{"model":"gpt-4o-mini","messages":[{"role":"user","content":"Hello"}]}' \
  | jq
```

The response body is the OpenAI chat completion JSON, unchanged. On budget exhaustion the proxy returns:

```json
{ "errors": [{ "status": 429, "detail": "Budget exceeded" }] }
```

---

## Checking and adjusting a token's budget

**Check spend:**

```sh
curl -s "https://ai-budget-proxy.fly.dev/tokens?email=owner@example.com" | jq
# returns limit, usage, and remaining in dollars
```

**Raise the limit:**

```ruby
ProxyToken.find_by(label: "my-app").update!(limit_millicents: 20 * 100_000)  # replace 20 with the new dollar cap
```

**Reset usage at the start of a billing period:**

```ruby
ProxyToken.find_by(label: "my-app").update!(usage_millicents: 0)
```

**Revoke a token:**

```ruby
ProxyToken.find_by(label: "my-app").update!(revoked: true)
```

---

## Security

### In transit
Outbound requests from the proxy to OpenAI are always HTTPS. Inbound TLS is provided by Fly.io's edge termination; `force_ssl` is enabled so the app refuses plain-HTTP connections.

### Credential handling
The proxy never stores upstream credentials. `X-Provider-Authorization` is read from the incoming request, held in memory for the duration of that request, and forwarded to OpenAI. It is not written to the database or any log.

### Log filtering
- Request body fields (`messages`, `prompt`, `input`, `content`) are masked as `[FILTERED]` in Rails parameter logs.
- `Authorization` and `X-Provider-Authorization` header values are redacted to `[REDACTED]` in any log line that includes them.

### Known caveat
Upstream error bodies in 502 responses may echo OpenAI's response verbatim. Treat 502 `detail` strings as untrusted until the sanitization ticket ships (see [Roadmap](#roadmap)).

---

## Configuration

Rate limits are read from environment variables on each request and can be adjusted without redeploying.

| ENV var | Default | Description |
|---|---|---|
| `RATE_LIMIT_PER_TOKEN_RPM` | `60` | Max requests per minute per proxy token on `POST /proxy` |
| `RATE_LIMIT_PER_IP_RPM` | `120` | Max requests per minute per IP on `POST /proxy` |
| `RATE_LIMIT_TOKENS_PER_IP_HOUR` | `10` | Max `POST /tokens` requests per hour per IP |
| `RATE_LIMIT_TOKENS_GET_PER_IP_HOUR` | `60` | Max `GET /tokens` requests per hour per IP |

Exceeding either proxy throttle returns `429` with a `Retry-After` header.

---

## Known limitations (this release)

- **Non-streaming only.** SSE/streaming requests are not supported. The Bun streamer sidecar is on the roadmap.
- **Token management via Rails console.** No self-service UI yet. Use `POST /tokens` and `GET /tokens?email=` for programmatic access, or the console for operator tasks.
- **Single hard cap per token.** Soft-threshold alerts (e.g. notify at 80%) are on the roadmap.
- **`gpt-4o-mini` pricing only.** Other models are billed at a conservative fallback rate (Post-MVP ticket). Prefer `gpt-4o-mini` for predictable costs today.

---

## Deployment

The proxy is deployed on [Fly.io](https://fly.io) (region: `ams`).

**Required secrets (set via `fly secrets set`):**

| Secret | Description |
|---|---|
| `RAILS_MASTER_KEY` | Contents of `config/master.key` |
| `SECRET_KEY_BASE` | Any secure random string (`rails secret`) |
| `DATABASE_URL` | PostgreSQL connection string |

**Deploy steps:**

```sh
# 1. Trigger a deploy (use the Fly UI button if behind a corporate SSL proxy)
fly deploy --app ai-budget-proxy

# 2. Run migrations
fly ssh console -C "/rails/bin/rails db:migrate"

# 3. Create the first token
fly ssh console --pty -C "/rails/bin/rails runner \"
  t = ProxyToken.create!(label: 'first', email: 'you@example.com', token: SecureRandom.hex(32), limit_millicents: 10 * 100_000)
  puts t.token
\""

# 4. Smoke test
curl -s https://ai-budget-proxy.fly.dev/up
```

See `docs/launch_plan.md` for the full runbook, troubleshooting, and corporate-network deploy workarounds.

---

## Roadmap

See [`TASKS.md`](TASKS.md) for what is coming next, including: unpriced-model fallback billing, streaming support (Bun sidecar), email confirmation on token creation, soft-cap alerts, and a React dashboard.
