# frozen_string_literal: true

# Enterprise: add MFA / custom role checks before super (e.g. prepend_mod_with).
module Enterprise
  module AiResolution
    module ApprovalDecisionService
      extend ActiveSupport::Concern
    end
  end
end
