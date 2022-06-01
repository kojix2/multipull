# frozen_string_literal: true

require 'optparse'
require_relative 'terminal_color'

module Multipull
  class Command
    include TerminalColor

    def initialize
      # @options = {}
      @dirs = []
    end

    def run
      parse_options
      main
    end

    private

    def parse_options
      OptionParser.new do |opts|
        opts.banner = 'Usage: multipull [options] [dir...]'

        opts.on('-v', '--version', 'Show version') do
          puts VERSION
          exit
        end

        opts.on('-h', '--help', 'Show help') do
          puts opts
          exit
        end
      end.parse!

      @dirs = ARGV.empty? ? ['.'] : ARGV
    end

    def start_banner(dirs)
      targets = blue(dirs.join(' '))
      puts bold("multipull: #{targets}")
    end

    def main(dirs = @dirs)
      start_banner(dirs)
      dirs.each do |dir|
        unless File.directory?(dir)
          puts magenta("#{dir} is not a directory")
          next
        end
        Dir.chdir(dir) do
          Dir.glob('*/').each do |subdir|
            puts blue(bold(subdir))
            Dir.chdir(subdir) do
              system('git pull')
            end
          end
        end
      end
    end
  end
end
