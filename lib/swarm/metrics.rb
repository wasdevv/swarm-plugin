# frozen_string_literal: true

require "date"
require "time"

module Swarm
  # Aggregates a list of Task records into a compact, greppable report.
  # Pure function of its input — no I/O, no globals — so specs stay trivial.
  module Metrics
    def self.call(tasks, now: Time.now.utc)
      out = []
      counts = tally(tasks, &:status)

      out << Color.bold("summary")
      out << "  total: #{tasks.size}"
      Task::STATUSES.each { |s| out << "  #{s.ljust(9)} #{counts.fetch(s, 0)}" }

      merged = counts.fetch("merged", 0)
      discarded = counts.fetch("discarded", 0)
      decided = merged + discarded
      finished_ok = counts.fetch("finished", 0) + merged
      finished_total = finished_ok + counts.fetch("failed", 0)
      out << ""
      out << Color.bold("outcomes")
      out << "  keeper rate:   #{pct(merged, decided)}  (#{merged}/#{decided} decided attempts kept)"
      out << "  agent ok rate: #{pct(finished_ok, finished_total)}  (#{finished_ok}/#{finished_total} runs exited 0)"

      out << ""
      out << Color.bold("elapsed (seconds)")
      %w[finished failed merged discarded].each do |s|
        secs = tasks.select { |t| t.status == s }.filter_map { |t| duration_seconds(t) }
        next if secs.empty?

        sorted = secs.sort
        out << "  #{s.ljust(9)} n=#{secs.size}  median=#{sorted[sorted.size / 2]}  min=#{sorted.first}  max=#{sorted.last}"
      end

      out << ""
      out << Color.bold("activity (last 7 days, UTC)")
      today = now.to_date
      (0..6).map { |d| today - d }.reverse.each do |day|
        n = tasks.count { |t| (Date.parse(t.started_at) rescue nil) == day }
        out << "  #{day} #{n}"
      end

      out << ""
      out << Color.bold("top repos")
      tally(tasks, &:repo_root).sort_by { |_, n| -n }.first(5).each do |repo, n|
        out << "  #{n.to_s.rjust(3)} #{repo}"
      end

      out << ""
      out << Color.bold("top prompts (first line)")
      tally(tasks) { |t| t.prompt_first_line }.sort_by { |_, n| -n }.first(5).each do |prompt, n|
        out << "  #{n.to_s.rjust(3)} #{truncate(prompt, 70)}"
      end

      out.join("\n")
    end

    def self.tally(items, &block)
      items.group_by(&block).transform_values(&:size)
    end

    def self.pct(numerator, denominator)
      return "—" if denominator.zero?

      "#{(100.0 * numerator / denominator).round}%"
    end

    def self.duration_seconds(task)
      started = Time.parse(task.started_at) rescue nil
      ended = task.finished_at ? (Time.parse(task.finished_at) rescue nil) : nil
      return nil unless started && ended

      (ended - started).to_i
    end

    def self.truncate(str, len)
      str.length > len ? "#{str[0, len - 1]}…" : str
    end
  end
end
