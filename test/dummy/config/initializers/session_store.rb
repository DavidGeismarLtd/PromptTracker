# frozen_string_literal: true

# Configure session storage to use cache store instead of cookies
# This allows storing larger session data (like conversation history) without
# hitting the 4KB cookie size limit.
#
# Sessions are stored in Redis with automatic expiration after 24 hours of inactivity.
# The "Reset" button in the playground clears the session immediately.

Rails.application.config.session_store :cache_store,
  key: "_prompt_tracker_session",
  expire_after: 24.hours  # Auto-cleanup after 24 hours of inactivity
