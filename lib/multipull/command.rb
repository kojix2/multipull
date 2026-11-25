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
      @success = true
    end

    def run
      parse_options
      main
      exit(1) unless @success
    end

    private

    def parse_options(argv = ARGV)
      opts = OptionParser.new
      opts.banner = 'Usage: multipull [options] [dir...] [-- git-pull-options...]'
      # Prevent abbreviations like -v from being expanded to --version
      opts.require_exact = true

      opts.on('--version', 'Show version') do
        puts "multipull #{VERSION}"
        exit
      end

      opts.on('-h', '--help', 'Show help') do
        puts opts
        exit
      end

      args = argv.dup
      passthrough = []
      if (i = args.index('--'))
        passthrough = args[(i + 1)..]
        args = args[0...i]
      end

      begin
        opts.parse!(args)
      rescue OptionParser::InvalidOption => e
        @git_opts += e.args
        retry
      end

      @git_opts += passthrough
      @dirs = args.empty? ? ['.'] : args
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
          @success = false
          next
        end

        skipped = []
        succeeded = []
        failed    = []
        Dir.chdir(dir) do
          Dir.glob('*/').each do |subdir|
            Dir.chdir(subdir) do
              dirname = subdir.delete_suffix('/')
              if File.exist?('.git')
                puts blue(bold(dirname))
              else
                skipped << dirname
                next
              end
              if system('git', 'pull', *@git_opts)
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
          @success = false
          warn \
            bold(magenta('Failed : ')) + failed.join(' ')
        end
      end
    end
  end
end
