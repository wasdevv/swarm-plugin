# frozen_string_literal: true

require "spec_helper"

RSpec.describe Swarm::Task do
  describe ".new_id" do
    it "returns a sortable, unique id shaped like YYYYMMDD-HHMM-xxxx" do
      id = described_class.new_id
      expect(id).to match(/\A\d{8}-\d{4}-[a-f0-9]{4}\z/)
    end

    it "generates different ids on successive calls" do
      expect(described_class.new_id).not_to eq(described_class.new_id)
    end
  end

  describe "#prompt_first_line" do
    it "returns the first line trimmed" do
      t = described_class.new(prompt: "Add pagination\nOn the Deals index\n")
      expect(t.prompt_first_line).to eq("Add pagination")
    end

    it "returns empty string when prompt is nil" do
      expect(described_class.new(prompt: nil).prompt_first_line).to eq("")
    end
  end

  describe "#elapsed" do
    it "returns seconds when under a minute" do
      t = described_class.new(started_at: (Time.now.utc - 12).iso8601)
      expect(t.elapsed).to match(/\A1[12]s\z/)
    end
  end
end
