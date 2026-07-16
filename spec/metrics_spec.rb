# frozen_string_literal: true

require "spec_helper"

RSpec.describe Swarm::Metrics do
  # Colors would insert ANSI codes into the strings we assert on. Force off.
  before { allow(Swarm::Color).to receive(:enabled?).and_return(false) }

  def task(overrides = {})
    Swarm::Task.new({
      id: "t-#{overrides[:id] || rand(1000)}",
      prompt: "generic prompt",
      repo_root: "/repo/one",
      parent_branch: "main",
      branch: "swarm/x",
      worktree_path: "/tmp/x",
      pid: 1,
      status: "finished",
      started_at: Time.now.utc.iso8601,
    }.merge(overrides))
  end

  it "prints an empty-friendly summary when no tasks" do
    out = described_class.call([])
    expect(out).to include("total: 0")
    expect(out).to include("keeper rate:   —")
  end

  it "counts tasks per status" do
    tasks = [
      task(status: "merged"),
      task(status: "merged"),
      task(status: "discarded"),
      task(status: "failed"),
      task(status: "finished"),
    ]
    out = described_class.call(tasks)
    expect(out).to include("total: 5")
    expect(out).to match(/merged\s+2/)
    expect(out).to match(/discarded\s+1/)
    expect(out).to match(/failed\s+1/)
    expect(out).to match(/finished\s+1/)
  end

  it "computes keeper rate from merged vs discarded only" do
    tasks = [task(status: "merged"), task(status: "merged"), task(status: "discarded")]
    out = described_class.call(tasks)
    expect(out).to include("keeper rate:   67%")
    expect(out).to include("(2/3 decided attempts kept)")
  end

  it "computes agent ok rate from finished+merged vs failed" do
    tasks = [
      task(status: "finished"),
      task(status: "merged"),
      task(status: "failed"),
      task(status: "failed"),
    ]
    out = described_class.call(tasks)
    expect(out).to include("agent ok rate: 50%")
  end

  it "reports elapsed medians per status when finished_at is set" do
    now = Time.now.utc
    tasks = [
      task(status: "finished", started_at: (now - 10).iso8601, finished_at: now.iso8601),
      task(status: "finished", started_at: (now - 30).iso8601, finished_at: now.iso8601),
      task(status: "finished", started_at: (now - 60).iso8601, finished_at: now.iso8601),
    ]
    out = described_class.call(tasks)
    expect(out).to include("finished  n=3  median=30")
  end

  it "buckets activity into last 7 days" do
    now = Time.utc(2026, 7, 15, 12, 0, 0)
    tasks = [
      task(id: 1, started_at: Time.utc(2026, 7, 15).iso8601),
      task(id: 2, started_at: Time.utc(2026, 7, 15).iso8601),
      task(id: 3, started_at: Time.utc(2026, 7, 13).iso8601),
      task(id: 4, started_at: Time.utc(2026, 6, 1).iso8601), # outside window
    ]
    out = described_class.call(tasks, now: now)
    expect(out).to include("2026-07-15 2")
    expect(out).to include("2026-07-13 1")
    expect(out).not_to include("2026-06-01")
  end

  it "ranks top repos" do
    tasks = [
      task(repo_root: "/repo/a"), task(repo_root: "/repo/a"),
      task(repo_root: "/repo/b"),
    ]
    out = described_class.call(tasks)
    expect(out).to match(/2 \/repo\/a/)
    expect(out).to match(/1 \/repo\/b/)
  end

  it "ranks top prompts by first line, truncating long ones" do
    long = "Add cursor pagination to DealsController and refactor while youre at it and also fix the flaky test that no one likes"
    tasks = [
      task(prompt: "Add pagination"), task(prompt: "Add pagination"),
      task(prompt: long),
    ]
    out = described_class.call(tasks)
    expect(out).to match(/2 Add pagination/)
    expect(out).to include("…") # long prompt got truncated
  end
end
