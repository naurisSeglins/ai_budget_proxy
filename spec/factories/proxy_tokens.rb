FactoryBot.define do
  factory :proxy_token do
    sequence(:email) { |n| "user#{n}@example.com" }
    token { SecureRandom.urlsafe_base64(32) }
    label { nil }
    limit_millicents { 1_000_000 }  # $10
    usage_millicents { 0 }
    revoked { false }

    trait :revoked do
      revoked { true }
    end

    trait :exceeded do
      limit_millicents { 1_000_000 }
      usage_millicents { 1_500_000 }
    end

    trait :with_remaining do
      limit_millicents { 1_000_000 }
      usage_millicents { 500_000 }
    end
  end
end
