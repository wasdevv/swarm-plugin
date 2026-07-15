# frozen_string_literal: true

require "spec_helper"

RSpec.describe Swarm::Color do
  around do |ex|
    original = ENV.to_h.slice("NO_COLOR", "FORCE_COLOR")
    ENV.delete("NO_COLOR")
    ENV.delete("FORCE_COLOR")
    ex.run
    original.each { |k, v| ENV[k] = v }
  end

  describe ".enabled?" do
    it "is false when NO_COLOR is set to a non-empty value" do
      ENV["NO_COLOR"] = "1"
      expect(described_class.enabled?).to be(false)
    end

    it "is true when FORCE_COLOR is set (even without a TTY)" do
      ENV["FORCE_COLOR"] = "1"
      expect(described_class.enabled?).to be(true)
    end

    it "NO_COLOR wins over FORCE_COLOR (no-color spec)" do
      ENV["NO_COLOR"] = "1"
      ENV["FORCE_COLOR"] = "1"
      expect(described_class.enabled?).to be(false)
    end
  end

  describe ".paint" do
    it "wraps text in ANSI codes when enabled" do
      ENV["FORCE_COLOR"] = "1"
      expect(described_class.paint("hi", :red)).to eq("\e[31mhi\e[0m")
    end

    it "returns the raw string when NO_COLOR is set" do
      ENV["NO_COLOR"] = "1"
      expect(described_class.paint("hi", :red)).to eq("hi")
    end

    it "returns raw string for unknown colors even when enabled" do
      ENV["FORCE_COLOR"] = "1"
      expect(described_class.paint("hi", :indigo)).to eq("hi")
    end
  end

  describe ".status" do
    before { ENV["FORCE_COLOR"] = "1" }

    it "colors running yellow, finished green, failed red" do
      expect(described_class.status("running")).to include("\e[33m")
      expect(described_class.status("finished")).to include("\e[32m")
      expect(described_class.status("failed")).to include("\e[31m")
    end

    it "falls back to reset when the status is unknown" do
      expect(described_class.status("weird")).to eq("weird")
    end
  end
end
