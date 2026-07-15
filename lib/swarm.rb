# frozen_string_literal: true

require_relative "swarm/task"
require_relative "swarm/store"
require_relative "swarm/git"
require_relative "swarm/runner"
require_relative "swarm/cli"

module Swarm
  VERSION = "0.1.0"
  MAX_PARALLEL = 4

  def self.run(args, cwd)
    CLI.new(cwd).run(args)
  end
end
