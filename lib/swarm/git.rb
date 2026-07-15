# frozen_string_literal: true

require "fileutils"
require "open3"

module Swarm
  # Thin wrappers around the git CLI. No third-party gems; every method returns
  # stdout on success and raises Swarm::Git::Error on non-zero exit.
  module Git
    class Error < StandardError; end

    def self.sh(*args, chdir: Dir.pwd)
      out, err, status = Open3.capture3("git", *args, chdir: chdir)
      raise Error, "git #{args.join(' ')} failed: #{err.strip}" unless status.success?

      out
    end

    def self.repo_root(cwd)
      sh("rev-parse", "--show-toplevel", chdir: cwd).strip
    rescue Error
      nil
    end

    def self.current_branch(cwd)
      sh("rev-parse", "--abbrev-ref", "HEAD", chdir: cwd).strip
    end

    def self.head_sha(cwd)
      sh("rev-parse", "HEAD", chdir: cwd).strip
    end

    def self.dirty?(cwd)
      !sh("status", "--porcelain", chdir: cwd).strip.empty?
    end

    def self.worktree_add(repo_root, path, branch, from_ref)
      FileUtils.mkdir_p(File.dirname(path))
      sh("worktree", "add", "-b", branch, path, from_ref, chdir: repo_root)
    end

    def self.worktree_remove(repo_root, path)
      sh("worktree", "remove", "--force", path, chdir: repo_root)
    rescue Error
      # If git doesn't recognize the worktree anymore, just delete the dir.
      FileUtils.rm_rf(path)
    end

    def self.branch_delete(repo_root, branch)
      sh("branch", "-D", branch, chdir: repo_root)
    rescue Error
      nil
    end

    def self.merge_base(cwd, a, b)
      sh("merge-base", a, b, chdir: cwd).strip
    end
  end
end
