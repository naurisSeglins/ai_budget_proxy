# ai_budget proxy

A stateless HTTP proxy that sits between your app and OpenAI and enforces a hard spend cap. When the cap is hit, requests stop — no runaway bills from a loop gone wrong or a forgotten test script.

Your OpenAI key never touches the proxy server. You supply it on each request and it is forwarded directly to OpenAI.

---

## Status

Public status page (monitored every minute):
**https://stats.uptimerobot.com/iksO5GXjsP**

Production endpoint: `https://ai-budget-proxy.fly.dev`

---

## Latency

Measured 2026-05-12, `gpt-4o-mini`, Fly.io `ams`, 200 requests:

```
p50  : 951 ms
p95  : 1678 ms
mean : 1108 ms
```

---

## Quick start

**1. Get a token**

```sh
curl -s -X POST https://ai-budget-proxy.fly.dev/tokens \
  -H "Content-Type: application/json" \
  -d '{"email":"you@example.com","limit":10,"label":"my-app"}' \
  | jq
```

`limit` is your spend cap in dollars. Returns `{ "token": "..." }` — save it.

**2. Send a request**

Two headers are required on every call to `POST /proxy`:

| Header | Value |
|---|---|
| `Authorization` | `Bearer <your-proxy-token>` |
| `X-Provider-Authorization` | `Bearer <your-openai-key>` |

```sh
curl -s -X POST https://ai-budget-proxy.fly.dev/proxy \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer <your-proxy-token>" \
  -H "X-Provider-Authorization: Bearer sk-..." \
  -d '{"model":"gpt-4o-mini","messages":[{"role":"user","content":"Hello"}]}' \
  | jq
```

The response is the OpenAI chat completion JSON, unchanged. When your budget is exhausted the proxy returns `429` before making any upstream call:

```json
{ "errors": [{ "status": 429, "detail": "Budget exceeded" }] }
```

**3. Check your spend**

```sh
curl -s "https://ai-budget-proxy.fly.dev/tokens?email=you@example.com" | jq
```

Returns `limit`, `usage`, and `remaining` in dollars for every token on that email.

---

## Security 

- Your OpenAI key is never stored. It is held in memory for the duration of the request and forwarded to OpenAI — it is never written to the database or any log.
- All traffic is HTTPS. Plain HTTP is refused.
- Request body fields (`messages`, `prompt`, `input`, `content`) are masked in logs. Auth header values are redacted.

---

## Rate limits

| Limit | Default |
|---|---|
| Requests per minute per token | 60 |
| Requests per minute per IP | 120 |

Exceeding either returns `429` with a `Retry-After` header.

---

## Known limitations

- **Non-streaming only.** SSE/streaming responses are not supported yet.

---

## Roadmap

Planned: streaming support, soft-cap alerts, and a React dashboard with account registration.
