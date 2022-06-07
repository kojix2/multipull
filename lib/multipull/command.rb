# frozen_string_literal: true

require 'optparse'
require_relative 'terminal_color'

module Multipull
  class Command
    include TerminalColor

    def initialize
      # @options = {}
      @dirs = []
      @git_opts = []
    end

    def run
      parse_options
      main
    end

    private

    def parse_options
      opts = OptionParser.new
      opts.banner = 'Usage: multipull [options] [dir...]'

      opts.on('--version', 'Show version') do
        puts "multipull #{VERSION}"
        exit
      end

      opts.on('--help', 'Show help') do
        puts opts
        exit
      end

      begin
        opts.parse!
      rescue OptionParser::InvalidOption => e
        @git_opts += e.args
        retry
      end

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

        skipped = []
        succeeded = []
        failed    = []
        Dir.chdir(dir) do
          Dir.glob('*/').each do |subdir|
            Dir.chdir(subdir) do
              dirname = subdir.delete_suffix('/')
              if File.directory?('.git')
                puts blue(bold(dirname))
              else
                skipped << dirname
                next
              end
              if system("git pull #{@git_opts.join(' ')}")
                succeeded << dirname
              else
                failed << dirname
              end
            end
          end
        end
        unless skipped.empty?
          warn \
            bold('Skipped : ') + skipped.join(' ')
        end
        unless succeeded.empty?
          warn \
            bold(green('Succeeded : ')) + succeeded.join(' ')
        end
        unless failed.empty?
          warn \
            bold(magenta('Failed : ')) + failed.join(' ')
        end
      end
    end
  end
end
