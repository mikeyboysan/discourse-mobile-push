# frozen_string_literal: true

class CreateMobilePushDevices < ActiveRecord::Migration[8.0]
  def change
    create_table :mobile_push_devices do |t|
      t.integer :user_id, null: false
      t.string :platform, null: false
      t.string :app_id, null: false
      t.string :device_identifier
      t.string :token, null: false
      t.string :app_version
      t.datetime :last_seen_at, null: false
      t.datetime :last_delivered_at
      t.datetime :last_failure_at
      t.string :last_failure_reason
      t.timestamps
    end

    add_index :mobile_push_devices, :token, unique: true
    add_index :mobile_push_devices,
              %i[user_id app_id device_identifier],
              unique: true,
              where: "device_identifier IS NOT NULL",
              name: "idx_mobile_push_devices_on_user_app_device"
    add_index :mobile_push_devices, %i[user_id last_seen_at]
    add_foreign_key :mobile_push_devices, :users, on_delete: :cascade
  end
end
