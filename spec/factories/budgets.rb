FactoryBot.define do
  factory :budget do
    limit_cents { 1000 }
    usage_cents { 0 }

    trait :exceeded do
      limit_cents { 1000 }
      usage_cents { 1000 }
    end

    trait :with_remaining do
      limit_cents { 1000 }
      usage_cents { 500 }
    end
  end
end
