# frozen_string_literal: true

require "open3"
require "shellwords"

module Swarm
  # Top-level dispatch for the six subcommands:
  #   spawn <n> "<prompt>"   list   diff <id>   merge <id>   discard <id>   pr <id>
  class CLI
    def initialize(cwd)
      @cwd = cwd
    end

    def run(args)
      cmd, *rest = args
      case cmd
      when "spawn"    then spawn_cmd(rest)
      when "list"     then list_cmd
      when "diff"     then diff_cmd(rest)
      when "merge"    then merge_cmd(rest)
      when "discard"  then discard_cmd(rest)
      when "pr"       then pr_cmd(rest)
      when nil, "-h", "--help" then help
      else "swarm: unknown command '#{cmd}' (try -h)"
      end
    end

    private

    def help
      <<~HELP
        swarm #{VERSION}
        Usage:
          swarm spawn <n> "<prompt>"   spawn N parallel Claude Code agents (1..#{MAX_PARALLEL})
          swarm list                   list swarm tasks in this repo
          swarm diff <task-id>         diff of a task's worktree vs merge-base
          swarm merge <task-id>        merge task branch (--no-ff) and remove worktree
          swarm discard <task-id>      remove worktree and delete branch without merging
          swarm pr <task-id>           push branch and open GitHub PR via gh
      HELP
    end

    def repo_root
      @repo_root ||= Git.repo_root(@cwd)
    end

    def require_repo!
      raise "not a git repository (from #{@cwd})" unless repo_root
    end

    # ─── spawn ──────────────────────────────────────────────────────────────

    def spawn_cmd(args)
      require_repo!
      n_str, *prompt_parts = args
      n = n_str.to_i
      prompt = prompt_parts.join(" ").strip
      return "usage: swarm spawn <n> \"<prompt>\"" if n < 1 || prompt.empty?
      return "swarm: n must be between 1 and #{MAX_PARALLEL}" if n > MAX_PARALLEL
      return "swarm: repo has uncommitted changes; commit or stash first" if Git.dirty?(repo_root)

      parent_branch = Git.current_branch(repo_root)
      from_ref = Git.head_sha(repo_root)
      lines = ["Spawning #{n} agent(s) from #{parent_branch} (#{from_ref[0, 7]}):"]

      n.times do
        task = build_task(parent_branch, prompt)
        Git.worktree_add(repo_root, task.worktree_path, task.branch, from_ref)
        Store.save(task)
        task.pid = Runner.spawn(task)
        Store.save(task)
        lines << "  #{task.id}  pid=#{task.pid}  #{task.worktree_path}"
      end

      lines << ""
      lines << "Use /swarm-plugin:list to check progress."
      lines.join("\n")
    end

    def build_task(parent_branch, prompt)
      id = Task.new_id
      Task.new(
        id: id,
        prompt: prompt,
        repo_root: repo_root,
        parent_branch: parent_branch,
        branch: "swarm/#{id}",
        worktree_path: File.join(repo_root, ".swarm", "worktrees", id),
      )
    end

    # ─── list ───────────────────────────────────────────────────────────────

    def list_cmd
      require_repo!
      tasks = Store.for_repo(repo_root).map { |t| refresh(t) }
      return "no swarm tasks in this repo yet — run /swarm-plugin:spawn" if tasks.empty?

      header = format("%-24s %-10s %-8s %s", "TASK ID", "STATUS", "ELAPSED", "PROMPT")
      rows = tasks.sort_by(&:started_at).reverse.map do |t|
        format("%-24s %-10s %-8s %s", t.id, t.status, t.elapsed, truncate(t.prompt_first_line, 60))
      end
      ([header, "-" * header.length] + rows).join("\n")
    end

    def refresh(task)
      return task unless task.running?

      if Runner.alive?(task.pid)
        task
      else
        task.finished_at = Time.now.utc.iso8601
        task.exit_code = read_exit_code(task)
        task.status = task.exit_code.to_i.zero? ? "finished" : "failed"
        Store.save(task)
      end
    end

    def read_exit_code(task)
      path = File.join(task.worktree_path, ".swarm", "logs", "exit_code")
      File.exist?(path) ? File.read(path).strip.to_i : nil
    end

    def truncate(str, n)
      str.length > n ? "#{str[0, n - 1]}…" : str
    end

    # ─── diff ───────────────────────────────────────────────────────────────

    def diff_cmd(args)
      require_repo!
      task = load!(args.first)
      base = Git.merge_base(task.worktree_path, task.parent_branch, "HEAD")
      out = []
      out << "commits since #{task.parent_branch}:"
      out << Git.sh("log", "--oneline", "#{base}..HEAD", chdir: task.worktree_path)
      out << "\ndiff #{base}..HEAD (committed):"
      out << Git.sh("diff", "#{base}..HEAD", chdir: task.worktree_path)
      uncommitted = Git.sh("diff", chdir: task.worktree_path)
      out << "\nuncommitted:\n#{uncommitted}" unless uncommitted.strip.empty?
      untracked = Git.sh("ls-files", "--others", "--exclude-standard", chdir: task.worktree_path)
      out << "\nuntracked:\n#{untracked}" unless untracked.strip.empty?
      out.join("\n")
    end

    # ─── merge ──────────────────────────────────────────────────────────────

    def merge_cmd(args)
      require_repo!
      task = load!(args.first)
      commit_pending!(task)
      Git.sh("checkout", task.parent_branch, chdir: task.repo_root)
      begin
        Git.sh("merge", "--no-ff", "-m", "Merge swarm task #{task.id}", task.branch, chdir: task.repo_root)
      rescue Git::Error => e
        Git.sh("merge", "--abort", chdir: task.repo_root)
        return "swarm: merge failed and was aborted (#{e.message}). Worktree kept at #{task.worktree_path}."
      end
      Git.worktree_remove(task.repo_root, task.worktree_path)
      Git.branch_delete(task.repo_root, task.branch)
      task.status = "merged"
      task.finished_at ||= Time.now.utc.iso8601
      Store.save(task)
      "swarm: merged #{task.id} into #{task.parent_branch} and removed worktree."
    end

    def commit_pending!(task)
      return unless Git.dirty?(task.worktree_path)

      Git.sh("add", "-A", chdir: task.worktree_path)
      msg = "swarm: #{task.id} — #{task.prompt_first_line}"
      Git.sh("commit", "-m", msg, chdir: task.worktree_path)
    end

    # ─── discard ────────────────────────────────────────────────────────────

    def discard_cmd(args)
      require_repo!
      task = load!(args.first)
      Runner.terminate(task.pid) if task.running?
      Git.worktree_remove(task.repo_root, task.worktree_path) if Dir.exist?(task.worktree_path)
      Git.branch_delete(task.repo_root, task.branch)
      task.status = "discarded"
      task.finished_at ||= Time.now.utc.iso8601
      Store.save(task)
      "swarm: discarded #{task.id}."
    end

    # ─── pr ─────────────────────────────────────────────────────────────────

    def pr_cmd(args)
      require_repo!
      task = load!(args.first)
      return "swarm: gh CLI not found on PATH" unless gh_available?

      commit_pending!(task)
      Git.sh("push", "-u", "origin", task.branch, chdir: task.worktree_path)
      title = task.prompt_first_line
      body = task.prompt
      out, err, status = Open3.capture3(
        "gh", "pr", "create",
        "--base", task.parent_branch,
        "--head", task.branch,
        "--title", title,
        "--body", body,
        chdir: task.worktree_path,
      )
      return "swarm: gh pr create failed: #{err.strip}" unless status.success?

      out.strip
    end

    def gh_available?
      ENV["PATH"].to_s.split(File::PATH_SEPARATOR).any? { |p| File.executable?(File.join(p, "gh")) }
    end

    # ─── shared ─────────────────────────────────────────────────────────────

    def load!(id)
      raise ArgumentError, "task id required" if id.nil? || id.empty?

      task = Store.load(id)
      raise ArgumentError, "task '#{id}' not found" unless task

      task
    end
  end
end
