# frozen_string_literal: true

require "fileutils"
require "shellwords"

module Swarm
  # Spawns `claude -p "<prompt>"` in a detached background process inside a
  # worktree. Stdout and stderr are redirected to log files under the worktree's
  # .swarm/logs/ directory so the user can tail them later.
  module Runner
    class Error < StandardError; end

    def self.spawn(task)
      raise Error, "claude CLI not found on PATH" unless claude_available?

      logs_dir = File.join(task.worktree_path, ".swarm", "logs")
      FileUtils.mkdir_p(logs_dir)

      stdout_log = File.join(logs_dir, "stdout.log")
      stderr_log = File.join(logs_dir, "stderr.log")
      exit_code_path = File.join(logs_dir, "exit_code")

      # Wrap in sh so we can capture claude's exit code after the process detaches.
      # The prompt is passed as an env var to avoid quoting hell in the shell.
      script = %(claude -p "$SWARM_PROMPT"; echo $? > #{Shellwords.escape(exit_code_path)})
      pid = Process.spawn(
        { "SWARM_TASK_ID" => task.id, "SWARM_PROMPT" => task.prompt },
        "sh", "-c", script,
        chdir: task.worktree_path,
        out: [stdout_log, "a"],
        err: [stderr_log, "a"],
      )
      Process.detach(pid)
      pid
    end

    def self.alive?(pid)
      return false unless pid

      Process.kill(0, pid)
      true
    rescue Errno::ESRCH, Errno::EPERM
      false
    end

    def self.terminate(pid)
      return unless pid && alive?(pid)

      Process.kill("TERM", pid)
      # Give it a beat, then SIGKILL if still around.
      sleep 0.5
      Process.kill("KILL", pid) if alive?(pid)
    rescue Errno::ESRCH
      nil
    end

    def self.claude_available?
      paths = ENV["PATH"].to_s.split(File::PATH_SEPARATOR)
      paths.any? { |p| File.executable?(File.join(p, "claude")) }
    end
  end
end
