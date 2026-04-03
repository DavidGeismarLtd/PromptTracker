# frozen_string_literal: true

module PromptTracker
  # ActionCable channel for real-time prompt version test updates.
  #
  # Clients subscribe to a specific prompt version and receive updates when:
  # - Any test in that version starts running
  # - Any test in that version completes (passed/failed/error)
  # - Test run status changes
  #
  # This is used on the tests index page to show real-time status updates
  # for all tests in a version.
  #
  # @example Subscribe from JavaScript
  #   consumer.subscriptions.create(
  #     { channel: "PromptTracker::AgentVersionChannel", agent_version_id: 123 },
  #     {
  #       received(data) {
  #         console.log("Test updated:", data);
  #         updateTestRow(data.test_id, data);
  #       }
  #     }
  #   );
  #
  class AgentVersionChannel < ApplicationCable::Channel
    # Subscribe to a specific prompt version
    def subscribed
      agent_version = AgentVersion.find_by(id: params[:agent_version_id])

      if agent_version
        stream_for agent_version
        Rails.logger.info "📡 Client subscribed to AgentVersionChannel for version #{agent_version.id}"
      else
        reject
        Rails.logger.warn "⚠️  Client tried to subscribe to non-existent version #{params[:agent_version_id]}"
      end
    end

    # Unsubscribe from the prompt version
    def unsubscribed
      Rails.logger.info "📡 Client unsubscribed from AgentVersionChannel"
    end
  end
end
