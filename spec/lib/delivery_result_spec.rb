# frozen_string_literal: true

RSpec.describe DiscourseMobilePush::DeliveryResult do
  it "defaults detail and retry_after to nil" do
    result = described_class.new(outcome: :delivered)

    expect(result).to have_attributes(outcome: :delivered, detail: nil, retry_after: nil)
  end

  it "answers predicates for each outcome" do
    result = described_class.new(outcome: :retryable, retry_after: 30)

    expect(result).to be_retryable
    expect(result).not_to be_delivered
    expect(result).not_to be_invalid_device
    expect(result).not_to be_config_error
    expect(result).not_to be_rejected
  end

  it "rejects an unknown outcome" do
    expect { described_class.new(outcome: :lost) }.to raise_error(ArgumentError, /unknown outcome/)
  end
end
