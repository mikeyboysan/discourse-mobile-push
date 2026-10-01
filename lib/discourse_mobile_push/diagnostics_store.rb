# frozen_string_literal: true

module DiscourseMobilePush
  class DiagnosticsStore
    Summary =
      Data.define(
        :last_success_at,
        :last_failure_at,
        :last_failure_detail,
        :last_config_error_at,
        :last_config_error_detail,
        :invalidated_count,
      )

    KEY = "discourse_mobile_push:diagnostics"
    CONFIG_ERROR_DEVICES_KEY = "discourse_mobile_push:config_error_devices"
    CONFIG_ERROR_RETENTION = 1.day

    def initialize(redis: Discourse.redis)
      @redis = redis
    end

    def record(result:, device_id: nil, at: Time.zone.now)
      case result.outcome
      when :delivered
        @redis.hset(KEY, "last_success_at", at.to_i)
      when :invalid_device
        @redis.hincrby(KEY, "invalidated_count", 1)
      else
        @redis.mapped_hmset(KEY, failure_fields(result, at))
      end
      update_config_error_devices(result, device_id, at) if device_id
    end

    def summary
      fields = @redis.hgetall(KEY)
      Summary.new(
        last_success_at: time_at(fields["last_success_at"]),
        last_failure_at: time_at(fields["last_failure_at"]),
        last_failure_detail: fields["last_failure_detail"],
        last_config_error_at: time_at(fields["last_config_error_at"]),
        last_config_error_detail: fields["last_config_error_detail"],
        invalidated_count: fields["invalidated_count"].to_i,
      )
    end

    # Distinct devices whose latest delivery since `since` was a configuration error.
    def config_error_device_count(since:)
      @redis.zcount(CONFIG_ERROR_DEVICES_KEY, since.to_i, "+inf")
    end

    private

    def failure_fields(result, at)
      detail = result.detail || result.outcome.to_s
      fields = { "last_failure_at" => at.to_i, "last_failure_detail" => detail }
      return fields if !result.config_error?

      fields.merge("last_config_error_at" => at.to_i, "last_config_error_detail" => detail)
    end

    def update_config_error_devices(result, device_id, at)
      if result.delivered? || result.invalid_device?
        @redis.zrem(CONFIG_ERROR_DEVICES_KEY, device_id.to_s)
      elsif result.config_error?
        track_config_error_device(device_id, at)
      end
    end

    def track_config_error_device(device_id, at)
      @redis.multi do |transaction|
        transaction.zadd(CONFIG_ERROR_DEVICES_KEY, at.to_i, device_id.to_s)
        transaction.zremrangebyscore(
          CONFIG_ERROR_DEVICES_KEY,
          "-inf",
          (at - CONFIG_ERROR_RETENTION).to_i,
        )
        transaction.expire(CONFIG_ERROR_DEVICES_KEY, CONFIG_ERROR_RETENTION.to_i)
      end
    end

    def time_at(epoch_seconds) = epoch_seconds.presence && Time.zone.at(epoch_seconds.to_i)
  end
end
