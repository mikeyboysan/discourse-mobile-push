# frozen_string_literal: true

RSpec.describe DiscourseMobilePush::PushMessage do
  def build(**overrides)
    attributes = { title: "Title", body: "Body", data: { "url" => "/t/1" }, priority: :normal }
    described_class.new(**attributes.merge(overrides))
  end

  it "exposes its attributes" do
    message = build(priority: :high)

    expect(message).to have_attributes(title: "Title", body: "Body", data: { "url" => "/t/1" })
    expect(message).to be_high_priority
  end

  it "is not high priority with normal priority" do
    expect(build(priority: :normal)).not_to be_high_priority
  end

  it "freezes its data" do
    expect(build.data).to be_frozen
  end

  it "rejects an unknown priority" do
    expect { build(priority: :urgent) }.to raise_error(ArgumentError, /unknown priority/)
  end

  it "rejects non-string data keys" do
    expect { build(data: { url: "/t/1" }) }.to raise_error(ArgumentError, /must be strings/)
  end

  it "rejects non-string data values" do
    expect { build(data: { "topic_id" => 1 }) }.to raise_error(ArgumentError, /must be strings/)
  end
end
