FactoryBot.define do
  factory :proxy_token do
    sequence(:email) { |n| "user#{n}@example.com" }
    token { SecureRandom.hex(32) }
    label { nil }
    limit_cents { 1000 }
    usage_cents { 0 }
    revoked { false }

    trait :revoked do
      revoked { true }
    end

    trait :exceeded do
      limit_cents { 1000 }
      usage_cents { 1500 }
    end

    trait :with_remaining do
      limit_cents { 1000 }
      usage_cents { 500 }
    end
  end
end
