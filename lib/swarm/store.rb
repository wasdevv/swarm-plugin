# frozen_string_literal: true

require "fileutils"
require "json"

module Swarm
  # JSON-file persistence for Task, one file per task under ~/.swarm/tasks/.
  #
  # This is a filesystem store on purpose: no daemon, no db, and every task
  # remains inspectable/deletable by hand — swarm-plugin is a wrapper, not a service.
  class Store
    def self.root
      ENV["SWARM_HOME"] || File.join(Dir.home, ".swarm")
    end

    def self.tasks_dir
      File.join(root, "tasks")
    end

    def self.path_for(task_id)
      File.join(tasks_dir, "#{task_id}.json")
    end

    def self.save(task)
      FileUtils.mkdir_p(tasks_dir)
      File.write(path_for(task.id), JSON.pretty_generate(task.to_h))
      task
    end

    def self.load(task_id)
      path = path_for(task_id)
      return nil unless File.exist?(path)

      Task.new(JSON.parse(File.read(path), symbolize_names: true))
    end

    def self.all
      return [] unless Dir.exist?(tasks_dir)

      Dir[File.join(tasks_dir, "*.json")].sort.map do |f|
        Task.new(JSON.parse(File.read(f), symbolize_names: true))
      rescue JSON::ParserError
        nil
      end.compact
    end

    def self.for_repo(repo_root)
      all.select { |t| t.repo_root == repo_root }
    end
  end
end
