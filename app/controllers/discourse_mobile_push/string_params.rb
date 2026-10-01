# frozen_string_literal: true

module DiscourseMobilePush
  module StringParams
    private

    def string_param(key, required: false)
      value = params[key]
      raise Discourse::InvalidParameters.new(key) if value.present? && !value.is_a?(String)
      raise ActionController::ParameterMissing.new(key) if required && value.blank?

      value.presence
    end
  end
end
