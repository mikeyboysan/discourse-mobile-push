# frozen_string_literal: true

RSpec.describe Jobs::DiscourseMobilePush::RemoveSignedOutDevices do
  fab!(:user)

  let!(:signed_out) do
    revoked_key = Fabricate(:user_api_key, user:, revoked_at: 1.minute.ago)
    Fabricate(:mobile_push_device, user:, user_api_key_id: revoked_key.id)
  end
  let!(:signed_in) { Fabricate(:mobile_push_device, user:) }

  before { enable_current_plugin }

  it "removes devices whose credential is no longer valid" do
    described_class.new.execute({})

    expect(DiscourseMobilePush::Device.all).to eq([signed_in])
  end

  it "does nothing while the plugin is disabled" do
    SiteSetting.mobile_push_enabled = false

    described_class.new.execute({})

    expect(DiscourseMobilePush::Device.count).to eq(2)
  end
end
