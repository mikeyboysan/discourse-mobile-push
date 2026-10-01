# frozen_string_literal: true

RSpec.describe DiscourseMobilePush do
  describe "request log filtering" do
    let(:filter) { ActiveSupport::ParameterFilter.new(Rails.application.config.filter_parameters) }

    it "filters a push token parameter" do
      expect(filter.filter("token" => "push-token-1")).to eq("token" => "[FILTERED]")
    end

    it "leaves parameters that merely contain the word token untouched" do
      expect(filter.filter("token_fingerprint" => "abc123")).to eq("token_fingerprint" => "abc123")
    end
  end
end
