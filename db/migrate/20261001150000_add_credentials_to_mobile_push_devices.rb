# frozen_string_literal: true

class AddCredentialsToMobilePushDevices < ActiveRecord::Migration[8.0]
  def change
    add_column :mobile_push_devices, :user_api_key_id, :bigint
    add_column :mobile_push_devices, :user_auth_token_id, :bigint
  end
end
