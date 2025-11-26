# frozen_string_literal: true

# == Schema Information
#
# Table name: prompt_tracker_evaluator_configs
#
#  config            :jsonb            not null
#  configurable_id   :bigint           not null
#  configurable_type :string           not null
#  created_at        :datetime         not null
#  enabled           :boolean          default(TRUE), not null
#  evaluation_mode   :string           default("scored"), not null
#  evaluator_key     :string           not null
#  id                :bigint           not null, primary key
#  threshold         :integer
#  updated_at        :datetime         not null
#
require "rails_helper"

RSpec.describe PromptTracker::EvaluatorConfig, type: :model do
  describe "associations" do
    it { should belong_to(:configurable) }
  end

  describe "polymorphic association" do
    let(:prompt) { create(:prompt) }
    let(:version) { create(:prompt_version, prompt: prompt) }
    let(:test) { create(:prompt_test, prompt_version: version) }

    it "can belong to a PromptVersion" do
      config = described_class.create!(
        configurable: version,
        evaluator_key: "test_evaluator",
        enabled: true
      )

      expect(config.configurable_type).to eq("PromptTracker::PromptVersion")
      expect(config.configurable).to eq(version)
    end

    it "can belong to a PromptTest" do
      config = described_class.create!(
        configurable: test,
        evaluator_key: "test_evaluator",
        enabled: true
      )

      expect(config.configurable_type).to eq("PromptTracker::PromptTest")
      expect(config.configurable).to eq(test)
    end
  end

  describe "validations" do
    subject { build(:evaluator_config) }

    it { should validate_presence_of(:evaluator_key) }
    it { should validate_presence_of(:evaluation_mode) }
    it { should validate_inclusion_of(:evaluation_mode).in_array(%w[scored binary]) }

    describe "uniqueness of evaluator_key" do
      it "validates uniqueness scoped to configurable" do
        prompt = create(:prompt)
        version = create(:prompt_version, prompt: prompt)
        create(:evaluator_config, configurable: version, evaluator_key: "test_evaluator")

        duplicate = build(:evaluator_config, configurable: version, evaluator_key: "test_evaluator")
        expect(duplicate).not_to be_valid
        expect(duplicate.errors[:evaluator_key]).to include("has already been taken")
      end

      it "allows same evaluator_key for different configurables" do
        prompt = create(:prompt)
        version1 = create(:prompt_version, prompt: prompt)
        version2 = create(:prompt_version, prompt: prompt)

        create(:evaluator_config, configurable: version1, evaluator_key: "test_evaluator")
        duplicate = build(:evaluator_config, configurable: version2, evaluator_key: "test_evaluator")

        expect(duplicate).to be_valid
      end
    end
  end

  describe "scopes" do
    let(:prompt) { create(:prompt) }
    let(:version) { create(:prompt_version, prompt: prompt) }

    describe ".enabled" do
      it "returns only enabled configs" do
        enabled1 = create(:evaluator_config, configurable: version, enabled: true)
        enabled2 = create(:evaluator_config, configurable: version, enabled: true, evaluator_key: "other")
        create(:evaluator_config, :disabled, configurable: version, evaluator_key: "disabled")

        expect(described_class.enabled).to contain_exactly(enabled1, enabled2)
      end
    end

    describe ".scored" do
      it "returns only scored evaluation mode configs" do
        scored1 = create(:evaluator_config, configurable: version, evaluation_mode: "scored")
        scored2 = create(:evaluator_config, configurable: version, evaluation_mode: "scored", evaluator_key: "other")
        create(:evaluator_config, configurable: version, evaluation_mode: "binary", evaluator_key: "binary")

        expect(described_class.scored).to contain_exactly(scored1, scored2)
      end
    end

    describe ".binary" do
      it "returns only binary evaluation mode configs" do
        create(:evaluator_config, configurable: version, evaluation_mode: "scored")
        binary = create(:evaluator_config, configurable: version, evaluation_mode: "binary", evaluator_key: "binary")

        expect(described_class.binary).to contain_exactly(binary)
      end
    end
  end

  describe "instance methods" do
    let(:prompt) { create(:prompt) }
    let(:version) { create(:prompt_version, prompt: prompt) }
    let(:config) { create(:evaluator_config, configurable: version, evaluator_key: "keyword") }

    describe "#scored?" do
      it "returns true when evaluation_mode is scored" do
        config.evaluation_mode = "scored"
        expect(config.scored?).to be true
      end

      it "returns false when evaluation_mode is binary" do
        config.evaluation_mode = "binary"
        expect(config.scored?).to be false
      end
    end

    describe "#binary?" do
      it "returns true when evaluation_mode is binary" do
        config.evaluation_mode = "binary"
        expect(config.binary?).to be true
      end

      it "returns false when evaluation_mode is scored" do
        config.evaluation_mode = "scored"
        expect(config.binary?).to be false
      end
    end

    describe "#name" do
      it "returns titleized evaluator_key when metadata not available" do
        config.evaluator_key = "my_custom_evaluator"
        allow(config).to receive(:evaluator_metadata).and_return(nil)

        expect(config.name).to eq("My Custom Evaluator")
      end

      it "returns name from metadata when available" do
        allow(config).to receive(:evaluator_metadata).and_return({ name: "Custom Name" })
        expect(config.name).to eq("Custom Name")
      end
    end

    describe "#description" do
      it "returns description from metadata when available" do
        allow(config).to receive(:evaluator_metadata).and_return({ description: "Test description" })
        expect(config.description).to eq("Test description")
      end

      it "returns nil when metadata not available" do
        allow(config).to receive(:evaluator_metadata).and_return(nil)
        expect(config.description).to be_nil
      end
    end
  end
end
