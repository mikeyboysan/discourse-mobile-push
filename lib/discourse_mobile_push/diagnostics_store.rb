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

    def initialize(redis: Discourse.redis)
      @redis = redis
    end

    def record(result:, at: Time.zone.now)
      case result.outcome
      when :delivered
        @redis.hset(KEY, "last_success_at", at.to_i)
      when :invalid_device
        @redis.hincrby(KEY, "invalidated_count", 1)
      else
        @redis.mapped_hmset(KEY, failure_fields(result, at))
      end
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

    private

    def failure_fields(result, at)
      detail = result.detail || result.outcome.to_s
      fields = { "last_failure_at" => at.to_i, "last_failure_detail" => detail }
      return fields if !result.config_error?

      fields.merge("last_config_error_at" => at.to_i, "last_config_error_detail" => detail)
    end

    def time_at(epoch_seconds) = epoch_seconds.presence && Time.zone.at(epoch_seconds.to_i)
  end
end
