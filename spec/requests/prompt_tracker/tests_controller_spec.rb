# frozen_string_literal: true

require "rails_helper"

RSpec.describe "PromptTracker::TestsController", type: :request do
  let(:prompt) { create(:agent) }
  let(:version) { create(:agent_version, agent: prompt, status: "active") }
  let(:test) { create(:test, testable: version) }
end
