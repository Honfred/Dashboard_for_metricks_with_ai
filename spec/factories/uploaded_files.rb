FactoryBot.define do
  factory :uploaded_file do
    sequence(:name) { |n| "file_#{n}.log" }
    file_type { "log" }

    after(:build) do |uploaded_file|
      next if uploaded_file.file.attached?

      uploaded_file.file.attach(
        io: StringIO.new("line 1\nline 2\n"),
        filename: "app.log",
        content_type: "text/plain"
      )
    end

    trait :image do
      file_type { "screenshot" }

      after(:build) do |uploaded_file|
        uploaded_file.file.detach if uploaded_file.file.attached?
        # Минимальный валидный PNG (1x1)
        png = [ "89504e470d0a1a0a0000000d494844520000000100000001080600000" \
                "01f15c4890000000d4944415478da63fcffff3f030005fe02fea7568c" \
                "0d0000000049454e44ae426082" ].pack("H*")
        uploaded_file.file.attach(io: StringIO.new(png), filename: "shot.png", content_type: "image/png")
      end
    end
  end
end
