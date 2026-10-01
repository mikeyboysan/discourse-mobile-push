# frozen_string_literal: true

RSpec.describe DiscourseMobilePush::NotificationListener do
  fab!(:user)

  let(:job) { Jobs::DiscourseMobilePush::DeliverToDevice }
  let(:provider) { MobilePushFakeProvider.new }
  let(:push_filters) { [] }
  let(:payload) do
    {
      notification_type: Notification.types[:replied],
      topic_id: 1,
      post_url: "/t/x/1/2",
      actions: [],
    }
  end

  def listen = described_class.new(provider:, push_filters:).call(user, payload)

  before { SiteSetting.mobile_push_enabled = true }

  it "enqueues one delivery job per device of the user" do
    devices = Fabricate.times(2, :mobile_push_device, user:)
    Fabricate(:mobile_push_device)

    listen

    expect(job.jobs.map { |enqueued| enqueued["args"].first["device_id"] }).to match_array(
      devices.map(&:id),
    )
  end

  it "passes only the alert fields to the job" do
    device = Fabricate(:mobile_push_device, user:)

    expect_enqueued_with(
      job:,
      args: {
        user_id: user.id,
        device_id: device.id,
        payload: {
          "notification_type" => Notification.types[:replied],
          "topic_id" => 1,
          "post_url" => "/t/x/1/2",
        },
        attempt: 1,
      },
    ) { listen }
  end

  context "when nothing should be delivered" do
    before { Fabricate(:mobile_push_device, user:) }

    it "skips while the plugin is disabled" do
      SiteSetting.mobile_push_enabled = false

      listen

      expect(job.jobs).to be_empty
    end

    context "when the provider is not configured" do
      let(:provider) { MobilePushFakeProvider.new(configured: false) }

      it "skips" do
        listen

        expect(job.jobs).to be_empty
      end
    end

    it "skips when a push notification filter rejects the alert" do
      push_filters << ->(filtered_user, filtered_payload) do
        !(filtered_user == user && filtered_payload[:topic_id] == 1)
      end

      listen

      expect(job.jobs).to be_empty
    end
  end

  it "does nothing for a user without devices" do
    listen

    expect(job.jobs).to be_empty
  end
end
