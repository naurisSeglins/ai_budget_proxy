# Be sure to restart your server when you modify this file.

# Configure parameters to be partially matched (e.g. passw matches password) and filtered from the log file.
# Use this to limit dissemination of sensitive information.
# See the ActiveSupport::ParameterFilter documentation for supported notations and behaviors.
Rails.application.config.filter_parameters += [
  # Standard sensitive fields
  :passw, :email, :secret, :token, :_key, :crypt, :salt, :certificate, :otp, :ssn, :cvv, :cvc,
  # AI request body — prompt content. OpenAI uses :messages and (legacy) :prompt;
  # other providers use :input or :content. Filtering all four covers current
  # and likely-future provider shapes so user prompts never land in logs.
  :messages, :prompt, :input, :content
]
