# frozen_string_literal: true

module PageObjects
  module Pages
    class AdminMobilePushDiagnostics < PageObjects::Pages::Base
      PATH = "/admin/plugins/discourse-mobile-push/diagnostics"

      def visit_page
        page.visit(PATH)
        self
      end

      def has_problem?(text) = page.has_css?(".mobile-push-health__problem", text:)

      def has_no_problem? = page.has_no_css?(".mobile-push-health__problem")

      def has_project_id?(project_id)
        page.has_css?(".mobile-push-health__project-id", text: project_id)
      end

      def has_device?(device) = page.has_css?(row_selector(device))

      def has_no_device?(device) = page.has_no_css?(row_selector(device))

      def device_row(device) = page.find(row_selector(device))

      def has_empty_notice? = page.has_css?(".mobile-push-devices__empty")

      def filter_by_username(username)
        page.find(".mobile-push-devices__username").fill_in(with: username)
        page.find(".mobile-push-devices__filter-button").click
        self
      end

      def load_more
        page.find(".mobile-push-devices__load-more").click
        self
      end

      def send_test(device)
        device_row(device).find(".mobile-push-device-row__send-test").click
        PageObjects::Components::Dialog.new.click_yes
        self
      end

      def remove(device)
        device_row(device).find(".mobile-push-device-row__remove").click
        PageObjects::Components::Dialog.new.click_danger
        self
      end

      def has_test_result?(device, text)
        page.has_css?("#{row_selector(device)} .mobile-push-device-row__test-result", text:)
      end

      private

      def row_selector(device) = ".mobile-push-device-row[data-device-id='#{device.id}']"
    end
  end
end
