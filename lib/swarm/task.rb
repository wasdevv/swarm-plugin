# frozen_string_literal: true

require "securerandom"
require "time"

module Swarm
  # Value object describing one swarm attempt: a worktree + branch running claude -p.
  #
  # Persisted as JSON at ~/.swarm/tasks/<id>.json (see Store). Status transitions:
  # running -> finished | failed | discarded, and finished -> merged after a merge.
  class Task
    STATUSES = %w[running finished failed merged discarded].freeze

    attr_accessor :id, :prompt, :repo_root, :parent_branch, :branch,
                  :worktree_path, :pid, :status, :started_at, :finished_at,
                  :exit_code

    def self.new_id
      # Human-scannable, sortable, unique enough for a single-user tool.
      # e.g. 20260715-1445-a3f2
      stamp = Time.now.utc.strftime("%Y%m%d-%H%M")
      rand = SecureRandom.hex(2)
      "#{stamp}-#{rand}"
    end

    def initialize(attrs = {})
      attrs.each { |k, v| public_send("#{k}=", v) }
      @started_at ||= Time.now.utc.iso8601
      @status ||= "running"
    end

    def to_h
      {
        id: id,
        prompt: prompt,
        repo_root: repo_root,
        parent_branch: parent_branch,
        branch: branch,
        worktree_path: worktree_path,
        pid: pid,
        status: status,
        started_at: started_at,
        finished_at: finished_at,
        exit_code: exit_code,
      }
    end

    def running?
      status == "running"
    end

    def finished?
      status == "finished"
    end

    def elapsed
      started = Time.parse(started_at) rescue nil
      return "?" unless started

      ended = finished_at ? (Time.parse(finished_at) rescue Time.now.utc) : Time.now.utc
      secs = (ended - started).to_i
      return "#{secs}s" if secs < 60
      return "#{secs / 60}m#{secs % 60}s" if secs < 3600

      "#{secs / 3600}h#{(secs % 3600) / 60}m"
    end

    def prompt_first_line
      (prompt || "").lines.first.to_s.strip
    end
  end
end
