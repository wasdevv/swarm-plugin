# frozen_string_literal: true

module Swarm
  # ANSI color helper. Respects the NO_COLOR spec (https://no-color.org/) and
  # disables color when stdout is not a TTY (e.g. piped to a file). Everything
  # runs in stdlib.
  module Color
    CODES = {
      reset: 0,
      bold: 1,
      dim: 2,
      red: 31,
      green: 32,
      yellow: 33,
      blue: 34,
      magenta: 35,
      cyan: 36,
      gray: 90,
    }.freeze

    STATUS_COLORS = {
      "running" => :yellow,
      "finished" => :green,
      "failed" => :red,
      "merged" => :cyan,
      "discarded" => :gray,
    }.freeze

    def self.enabled?
      return false if ENV["NO_COLOR"] && !ENV["NO_COLOR"].empty?
      return true if ENV["FORCE_COLOR"] && !ENV["FORCE_COLOR"].empty?

      $stdout.tty?
    end

    def self.paint(str, color)
      return str.to_s unless enabled? && CODES.key?(color)

      "\e[#{CODES[color]}m#{str}\e[#{CODES[:reset]}m"
    end

    def self.status(name)
      color = STATUS_COLORS[name]
      color ? paint(name, color) : name.to_s
    end

    def self.bold(str)
      paint(str, :bold)
    end

    def self.dim(str)
      paint(str, :dim)
    end
  end
end
