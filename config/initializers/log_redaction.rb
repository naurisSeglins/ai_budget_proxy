# Wrap Rails.logger's formatter so that any log message passing through it has
# Authorization / X-Provider-Authorization bearer values redacted. This is a
# defense-in-depth measure — Rails 8 default logging does not include request
# headers, but log shippers and custom debug logging often do, and this filter
# catches them at the formatter layer regardless of source.
#
# Filter for request body fields (:messages, :prompt, :input, :content) is
# handled separately in filter_parameter_logging.rb via Rails' filter_parameters
# config, which runs at the params level before the message reaches a formatter.

require "delegate"

# Wrap the existing formatter via SimpleDelegator so push_tags/pop_tags and any
# other formatter methods (used by ActiveSupport::TaggedLogging) keep working
# while #call post-processes the message.
class RedactingFormatter < SimpleDelegator
  def call(severity, time, progname, msg)
    __getobj__.call(severity, time, progname, LogRedaction.redact(msg))
  end
end

Rails.application.config.after_initialize do
  next if Rails.logger.nil? || Rails.logger.formatter.nil?
  next if Rails.logger.formatter.is_a?(RedactingFormatter) # idempotent on reload

  Rails.logger.formatter = RedactingFormatter.new(Rails.logger.formatter)
end
