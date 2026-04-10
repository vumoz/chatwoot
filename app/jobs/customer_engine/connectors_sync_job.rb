# frozen_string_literal: true

module CustomerEngine
  class ConnectorsSyncJob < ApplicationJob
    queue_as :low

    def perform
      CustomerEngine::Connector.enabled.find_each do |connector|
        CustomerEngine::ConnectorSyncService.new(connector).perform
      rescue StandardError => e
        Rails.logger.error(
          "[CustomerEngine::ConnectorsSyncJob] connector=#{connector.id} #{e.class}: #{e.message}"
        )
        connector.update(last_error: "#{e.class}: #{e.message}")
      end
    end
  end
end
