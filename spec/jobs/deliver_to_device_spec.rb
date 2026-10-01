# frozen_string_literal: true

RSpec.describe Jobs::DiscourseMobilePush::DeliverToDevice do
  fab!(:user)
  fab!(:device) { Fabricate(:mobile_push_device, user:) }

  let(:provider) { MobilePushFakeProvider.new }
  let(:payload) do
    { "notification_type" => Notification.types[:replied], "post_url" => "/t/x/1/2" }
  end

  def args(**overrides) =
    { user_id: user.id, device_id: device.id, payload:, attempt: 1, **overrides }

  def execute(**overrides) = described_class.new.execute(args(**overrides).with_indifferent_access)

  before do
    SiteSetting.mobile_push_enabled = true
    DiscourseMobilePush.stubs(:provider).returns(provider)
  end

  it "delivers the alert to the device" do
    execute

    delivery = provider.deliveries.sole
    expect(delivery[:token]).to eq(device.token)
    expect(delivery[:message].data["url"]).to eq("http://test.localhost/t/x/1/2")
  end

  it "builds the message in the user's locale" do
    SiteSetting.allow_user_locale = true
    user.update!(locale: "de")
    TranslationOverride.upsert!(
      "de",
      DiscourseMobilePush::PayloadBuilder::GENERIC_BODY_TRANSLATION,
      "Neu",
    )

    execute

    expect(provider.deliveries.sole[:message].body).to eq("Neu")
  end

  it "does nothing while the plugin is disabled" do
    SiteSetting.mobile_push_enabled = false

    execute

    expect(provider.deliveries).to be_empty
  end

  it "does nothing when the device no longer exists" do
    device_id = device.id
    device.destroy!

    execute(device_id:)

    expect(provider.deliveries).to be_empty
  end

  it "does nothing when the device belongs to another user" do
    execute(user_id: Fabricate(:user).id)

    expect(provider.deliveries).to be_empty
  end

  it "does nothing when the user no longer exists" do
    execute(user_id: -999)

    expect(provider.deliveries).to be_empty
  end

  context "with a retryable outcome" do
    let(:provider) { MobilePushFakeProvider.new(outcome: :retryable, detail: "HTTP 503") }

    before { freeze_time }

    it "re-enqueues itself with exponential backoff and the next attempt number" do
      expect_enqueued_with(
        job: described_class,
        args: args(attempt: 3).except(:payload),
        at: 60.seconds.from_now,
      ) { execute(attempt: 2) }
    end

    it "treats a missing attempt number as the first attempt" do
      expect_enqueued_with(
        job: described_class,
        args: {
          attempt: 2,
        },
        at: described_class::BASE_BACKOFF_SECONDS.seconds.from_now,
      ) { execute(attempt: nil) }
    end

    it "waits at least as long as the provider's Retry-After" do
      provider = MobilePushFakeProvider.new(outcome: :retryable, retry_after: 600)
      DiscourseMobilePush.stubs(:provider).returns(provider)

      expect_enqueued_with(job: described_class, at: 600.seconds.from_now) { execute }
    end

    it "caps the backoff" do
      provider = MobilePushFakeProvider.new(outcome: :retryable, retry_after: 86_400)
      DiscourseMobilePush.stubs(:provider).returns(provider)

      expect_enqueued_with(
        job: described_class,
        at: described_class::MAX_BACKOFF_SECONDS.seconds.from_now,
      ) { execute }
    end

    it "gives up after the last attempt and logs once" do
      Rails.logger.stubs(:warn)
      Rails.logger.expects(:warn).with(regexp_matches(/after 5 attempts: HTTP 503/)).once

      execute(attempt: described_class::MAX_ATTEMPTS)

      expect(described_class.jobs).to be_empty
    end
  end

  it "does not retry configuration errors" do
    DiscourseMobilePush.stubs(:provider).returns(MobilePushFakeProvider.new(outcome: :config_error))

    execute

    expect(described_class.jobs).to be_empty
  end
end
