# frozen_string_literal: true

require 'optparse'
require_relative 'terminal_color'

module Multipull
  class Command
    include TerminalColor

    def initialize
      @dir = nil
    end

    def run
      parse_options
      main
    end

    private

    def parse_options
      OptionParser.new do |opts|
        opts.banner = 'Usage: multipull [options] [dir]'

        opts.on('-v', '--version', 'Show version') do
          puts VERSION
          exit
        end

        opts.on('-h', '--help', 'Show help') do
          puts opts
          exit
        end
      end.parse!

      @dir = ARGV.shift || '.'
    end

    def main
      Dir.chdir(@dir) do
        Dir.glob('*/').each do |dir|
          puts blue(bold(dir))
          system("git -C #{dir} pull")
        end
      end
    end
  end
end
