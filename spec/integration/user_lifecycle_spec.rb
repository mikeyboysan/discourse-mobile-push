# frozen_string_literal: true

RSpec.describe "Mobile push devices across the user lifecycle" do
  fab!(:admin)
  fab!(:user)

  it "removes a user's devices when the user is deleted" do
    device = Fabricate(:mobile_push_device, user:)

    UserDestroyer.new(admin).destroy(user)

    expect(DiscourseMobilePush::Device.exists?(device.id)).to eq(false)
  end

  it "removes a user's devices when the user is anonymised, even with the plugin disabled" do
    SiteSetting.mobile_push_enabled = false
    device = Fabricate(:mobile_push_device, user:)

    UserAnonymizer.make_anonymous(user, admin)

    expect(DiscourseMobilePush::Device.exists?(device.id)).to eq(false)
  end
end
