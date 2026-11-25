# frozen_string_literal: true

require 'open3'
require 'optparse'
require 'rbconfig'
require_relative 'terminal_color'

module Multipull
  class Command
    include TerminalColor

    def initialize
      # @options = {}
      @dirs = []
      @git_opts = []
      @jobs = 1
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

      opts.on('-P', '--parallel N', Integer, 'Number of repositories to pull in parallel (default: 1)') do |n|
        raise OptionParser::InvalidArgument, n.to_s if n < 1

        @jobs = n
      end

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
      rescue OptionParser::ParseError => e
        warn "multipull: #{e.message}"
        exit 1
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

        repos, skipped = Dir.glob('*/', base: dir)
                            .map { |subdir| subdir.delete_suffix('/') }
                            .partition { |name| File.exist?(File.join(dir, name, '.git')) }
        results = @jobs > 1 ? pull_parallel(dir, repos) : pull_sequential(dir, repos)
        succeeded, failed = repos.partition { |name| results[name] }

        unless skipped.empty?
          warn \
            bold('Skipped : ') + skipped.join(' ')
        end
        unless succeeded.empty?
          warn \
            bold(green('Succeeded : ')) + succeeded.join(' ')
        end
        next if failed.empty?

        @success = false
        warn \
          bold(magenta('Failed : ')) + failed.join(' ')
      end
    end

    def pull_sequential(dir, repos)
      repos.to_h do |name|
        puts blue(bold(name))
        [name, system('git', 'pull', *@git_opts, chdir: File.join(dir, name)) == true]
      end
    end

    # Each repository's output is buffered and printed as a single block
    # when it finishes, so that output from different repositories never interleaves.
    def pull_parallel(dir, repos)
      queue = Queue.new
      repos.each { |name| queue << name }
      queue.close
      results = {}
      mutex = Mutex.new

      workers = Array.new([@jobs, repos.size].min) do
        Thread.new do
          while (name = queue.pop)
            output, ok = capture_pull(File.join(dir, name))
            mutex.synchronize do
              results[name] = ok
              puts blue(bold(name))
              print output
              puts unless output.empty? || output.end_with?("\n")
              $stdout.flush
            end
          end
        end
      end
      workers.each(&:join)
      results
    end

    def capture_pull(path)
      # A new session prevents configured SSH commands from reading /dev/tty,
      # while preserving their identity files, ports, and other options.
      Open3.popen2e(non_interactive_env(path), RbConfig.ruby, '-e',
                    'Process.setsid if Process.respond_to?(:setsid); exec(*ARGV)',
                    '--', 'git', 'pull', *@git_opts, chdir: path) do |stdin, output, child|
        stdin.close
        begin
          [output.read, child.value.success?]
        ensure
          # Detached children do not receive the parent's terminal signals.
          stop_pull(child.pid) if child.alive?
        end
      end
    rescue SystemCallError => e
      ["#{e.message}\n", false]
    end

    def stop_pull(pid)
      targets = Process.respond_to?(:setsid) ? [-pid, pid] : [pid]
      targets.each do |target|
        Process.kill('KILL', target)
        break
      rescue Errno::ESRCH
        # The child may exit, or not have created its session yet.
        next
      end
    end

    # Prompts cannot be answered while running in parallel, so make git and ssh
    # fail instead of waiting for input.
    def non_interactive_env(path)
      env = {
        'GIT_TERMINAL_PROMPT' => '0',
        'GIT_ASKPASS' => '',
        'SSH_ASKPASS' => '',
        'SSH_ASKPASS_REQUIRE' => 'never'
      }
      unless ENV['GIT_SSH_COMMAND'] || ENV['GIT_SSH'] || ssh_command_configured?(path)
        env['GIT_SSH_COMMAND'] = 'ssh -o BatchMode=yes'
      end
      env
    end

    def ssh_command_configured?(path)
      _output, status = Open3.capture2e('git', 'config', '--get', 'core.sshCommand', chdir: path)
      status.success?
    rescue SystemCallError
      false
    end
  end
end
