# Defensive layer: scrub bearer values from any log line that includes the
# Authorization or X-Provider-Authorization header. Rails 8's default formatter
# does not log request headers, so this exists to guard against future log
# shippers (Lograge, Datadog, ELK) and ad-hoc debug logging that might.
module LogRedaction
  REDACTORS = [
    [ /(Authorization\s*[=:]\s*Bearer\s+)\S+/i, '\1[REDACTED]' ],
    [ /(X[-_]Provider[-_]Authorization\s*[=:]\s*Bearer\s+)\S+/i, '\1[REDACTED]' ]
  ].freeze

  def self.redact(text)
    REDACTORS.reduce(text.to_s) { |s, (pattern, replacement)| s.gsub(pattern, replacement) }
  end
end
