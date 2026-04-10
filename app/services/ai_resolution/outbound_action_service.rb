# frozen_string_literal: true

module AiResolution
  class OutboundActionService
    def initialize(attempt:, decision:)
      @attempt = attempt
      @decision = decision
      @signal = decision.ai_review_signal
      @account = attempt.account
      @policy = CustomerEngine::TenantPolicy.new(@account)
    end

    def perform
      return {} if @signal.blank?
      return {} unless auto_path? || agent_assist_path?

      out = {}
      if @policy.generate_draft_reply?
        draft = DraftReplyService.new(account: @account, signal: @signal).perform
        out['draft_reply'] = draft if draft.present?
      end

      if auto_path?
        if @policy.live_zendesk_public_comment? &&
           @signal.source_platform == 'zendesk' &&
           out['draft_reply'].present?
          post_zendesk_comment(out)
        end

        if @policy.live_google_review_reply? &&
           @signal.source_platform == 'google_business' &&
           out['draft_reply'].present?
          post_google_reply(out)
        end

        if @policy.live_yelp_public_reply? &&
           @signal.source_platform == 'yelp_fusion' &&
           out['draft_reply'].present?
          post_yelp_reply(out)
        end
      end

      if @policy.post_draft_as_private_note? &&
         @signal.conversation_id.present? &&
         out['draft_reply'].present?
        post_chatwoot_private_note(out)
      end

      out
    end

    private

    def auto_path?
      @decision.auto_reply? || @decision.auto_resolve?
    end

    def agent_assist_path?
      @decision.agent_assist?
    end

    def post_zendesk_comment(out)
      ticket_id = @signal.source_message_id
      return if ticket_id.blank?

      connector = @account.customer_engine_connectors.enabled.find_by(provider: 'zendesk')
      return if connector.blank?

      s = connector.settings
      client = Integrations::CustomerEngine::ZendeskClient.new(
        subdomain: s['subdomain'],
        email: s['email'],
        api_token: s['api_token']
      )
      client.add_public_comment(ticket_id, out['draft_reply'])
      out['zendesk_public_comment'] = 'posted'
    rescue StandardError => e
      out['zendesk_public_comment_error'] = "#{e.class}: #{e.message}"
    end

    def post_google_reply(out)
      review_name = google_review_resource_name
      return if review_name.blank?

      connector = @account.customer_engine_connectors.enabled.find_by(provider: 'google_business')
      return if connector.blank?

      s = connector.settings
      client = Integrations::CustomerEngine::GoogleBusinessClient.new(
        client_id: s['oauth_client_id'],
        client_secret: s['oauth_client_secret'],
        refresh_token: s['oauth_refresh_token'],
        account_resource_name: s['account_resource_name'],
        location_resource_name: s['location_resource_name']
      )
      client.update_reply(review_name, out['draft_reply'])
      out['google_review_reply'] = 'posted'
    rescue StandardError => e
      out['google_review_reply_error'] = "#{e.class}: #{e.message}"
    end

    def post_yelp_reply(out)
      review_id = @signal.source_message_id
      return if review_id.blank?

      connector = @account.customer_engine_connectors.enabled.find_by(provider: 'yelp_fusion')
      return if connector.blank?

      token = connector.settings['partner_r2r_access_token'].presence
      return if token.blank?

      client = Integrations::CustomerEngine::YelpPartnerClient.new(access_token: token)
      client.respond_to_review(review_id, out['draft_reply'])
      out['yelp_public_reply'] = 'posted'
    rescue StandardError => e
      out['yelp_public_reply_error'] = "#{e.class}: #{e.message}"
    end

    def google_review_resource_name
      full = @signal.source_payload&.dig('review', 'name')
      return full.to_s if full.present?

      connector = @account.customer_engine_connectors.enabled.find_by(provider: 'google_business')
      return if connector.blank?

      s = connector.settings
      a = s['account_resource_name'].to_s.sub(%r{\A/}, '').sub(%r{/\z}, '')
      l = s['location_resource_name'].to_s.sub(%r{\A/}, '').sub(%r{/\z}, '')
      id = @signal.source_message_id.to_s
      return if a.blank? || l.blank? || id.blank?

      "#{a}/#{l}/reviews/#{id}"
    end

    def post_chatwoot_private_note(out)
      conversation = Conversation.find_by(id: @signal.conversation_id, account_id: @account.id)
      return if conversation.blank?

      msg = ChatwootPrivateNoteService.new(
        account: @account,
        attempt: @attempt,
        conversation: conversation,
        draft_text: out['draft_reply']
      ).perform
      out['chatwoot_private_note'] = 'posted' if msg.present?
    rescue StandardError => e
      out['chatwoot_private_note_error'] = "#{e.class}: #{e.message}"
    end
  end
end

AiResolution::OutboundActionService.prepend_mod_with('AiResolution::OutboundActionService')
