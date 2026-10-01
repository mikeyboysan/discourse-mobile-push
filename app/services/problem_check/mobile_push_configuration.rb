# frozen_string_literal: true

class ProblemCheck::MobilePushConfiguration < ProblemCheck
  self.priority = "high"

  CONFIG_ERRORS_TRANSLATION = "dashboard.problem.mobile_push_config_errors"

  def call
    case DiscourseMobilePush::HealthCheck.new.problem
    when :not_configured
      problem
    when :config_errors
      problem(override_key: CONFIG_ERRORS_TRANSLATION)
    else
      no_problem
    end
  end
end
