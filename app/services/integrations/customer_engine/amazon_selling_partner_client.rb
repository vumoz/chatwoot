# frozen_string_literal: true

# Amazon Selling Partner API product/customer feedback requires LWA + AWS SigV4 signing.
# This client is a structured placeholder: enable `stub_mode` in connector settings to return [].without HTTP.
# Production use should extend this class with full SP-API signing (see Amazon docs).
module Integrations
  module CustomerEngine
    class AmazonSellingPartnerClient
      def initialize(settings)
        @settings = settings.deep_stringify_keys
      end

      # Returns [] unless stub_mode — real implementation requires registered SP-API app + IAM role.
      def fetch_review_signals
        return [] if ActiveModel::Type::Boolean.new.cast(@settings['stub_mode'])

        raise(
          'Amazon SP-API review ingestion requires a configured Selling Partner integration. ' \
          'Set settings["stub_mode"]=true to skip sync, or implement SP-API calls in ' \
          'Integrations::CustomerEngine::AmazonSellingPartnerClient.'
        )
      end
    end
  end
end
