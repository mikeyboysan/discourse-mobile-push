# frozen_string_literal: true

RSpec.describe DiscourseMobilePush::Fcm::ServiceAccount do
  let(:invalid_credentials) { DiscourseMobilePush::Fcm::InvalidCredentials }

  describe ".parse" do
    it "reads the service account fields" do
      account = described_class.parse(fcm_service_account_json)

      expect(account).to have_attributes(
        project_id: "example-project",
        client_email: "push@example-project.iam.gserviceaccount.com",
        private_key_id: "key-id-1",
        token_uri: "https://oauth2.googleapis.com/token",
      )
      expect(account.private_key.public_to_der).to eq(fcm_private_key.public_to_der)
    end

    it "prefers the project id override" do
      account = described_class.parse(fcm_service_account_json, project_id_override: "other")

      expect(account.project_id).to eq("other")
    end

    it "defaults the token URI when absent" do
      account = described_class.parse(fcm_service_account_json(token_uri: nil))

      expect(account.token_uri).to eq(described_class::DEFAULT_TOKEN_URI)
    end

    it "allows a missing private key id" do
      account = described_class.parse(fcm_service_account_json(private_key_id: nil))

      expect(account.private_key_id).to be_nil
    end

    it "rejects blank JSON" do
      expect { described_class.parse("") }.to raise_error(invalid_credentials, /missing/)
    end

    it "rejects malformed JSON without echoing it" do
      expect { described_class.parse("{secret-material") }.to raise_error(
        invalid_credentials,
        "service account JSON is not valid JSON",
      )
    end

    it "rejects JSON that is not an object" do
      expect { described_class.parse("[]") }.to raise_error(
        invalid_credentials,
        /must be an object/,
      )
    end

    %w[project_id client_email private_key].each do |field|
      it "rejects a missing #{field}" do
        json = fcm_service_account_json(field.to_sym => nil)

        expect { described_class.parse(json) }.to raise_error(invalid_credentials, /#{field}/)
      end
    end

    it "rejects a required field that is not a string" do
      json = fcm_service_account_json(project_id: 123)

      expect { described_class.parse(json) }.to raise_error(invalid_credentials, /project_id/)
    end

    it "rejects an invalid private key" do
      json = fcm_service_account_json(private_key: "not a key")

      expect { described_class.parse(json) }.to raise_error(invalid_credentials, /valid RSA key/)
    end

    it "rejects a public key in place of the private key" do
      json = fcm_service_account_json(private_key: fcm_private_key.public_to_pem)

      expect { described_class.parse(json) }.to raise_error(invalid_credentials, /private key/)
    end

    it "rejects a token URI that is not https" do
      json = fcm_service_account_json(token_uri: "http://oauth2.googleapis.com/token")

      expect { described_class.parse(json) }.to raise_error(invalid_credentials, /token_uri/)
    end

    it "rejects a token URI that cannot be parsed" do
      json = fcm_service_account_json(token_uri: "https://oauth2.googleapis.com/to ken")

      expect { described_class.parse(json) }.to raise_error(invalid_credentials, /not a valid URL/)
    end

    it "rejects a token URI outside googleapis.com" do
      json = fcm_service_account_json(token_uri: "https://evil.example.com/token")

      expect { described_class.parse(json) }.to raise_error(invalid_credentials, /token_uri/)
    end
  end

  describe "#fingerprint" do
    it "is stable for the same credentials" do
      first = described_class.parse(fcm_service_account_json)
      second = described_class.parse(fcm_service_account_json)

      expect(first.fingerprint).to eq(second.fingerprint)
    end

    it "changes with the client email" do
      first = described_class.parse(fcm_service_account_json)
      second = described_class.parse(fcm_service_account_json(client_email: "other@example.com"))

      expect(first.fingerprint).not_to eq(second.fingerprint)
    end
  end

  it "does not expose key material when inspected" do
    account = described_class.parse(fcm_service_account_json)

    expect(account.inspect).not_to include("PRIVATE KEY")
  end
end
