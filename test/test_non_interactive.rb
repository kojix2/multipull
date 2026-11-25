# frozen_string_literal: true

require_relative 'test_helper'
require 'json'
require 'pty'
require 'shellwords'

class TestNonInteractive < Test::Unit::TestCase
  include MultipullTestHelper

  def setup
    @tmp = Dir.mktmpdir('multipull-test')
    @ws = File.join(@tmp, 'ws')
    @repo = File.join(@ws, 'repo')
    FileUtils.mkdir_p(@repo)
    git('init', '-q', @repo, chdir: @tmp)

    bin = File.join(@tmp, 'bin')
    FileUtils.mkdir_p(bin)
    @askpass_log = File.join(@tmp, 'askpass.log')
    @ssh_log = File.join(@tmp, 'ssh.log')
    @env = {
      'PATH' => "#{bin}#{File::PATH_SEPARATOR}#{ENV.fetch('PATH')}",
      'GIT_ASKPASS' => nil, 'SSH_ASKPASS' => nil, 'SSH_ASKPASS_REQUIRE' => 'force',
      'GIT_SSH' => nil, 'GIT_SSH_COMMAND' => nil, 'GIT_SSH_VARIANT' => 'ssh',
      'ASKPASS_LOG' => @askpass_log, 'SSH_LOG' => @ssh_log
    }

    @askpass = File.join(bin, 'askpass')
    write_executable(@askpass, <<~SH)
      #!/bin/sh
      echo invoked >> "$ASKPASS_LOG"
      echo answer
    SH
    write_executable(File.join(bin, 'git-remote-auth-check'), <<~SH)
      #!/bin/sh
      printf 'protocol=https\nhost=example.invalid\n\n' | git -c credential.helper= credential fill >/dev/null
      exit 1
    SH
    git('config', 'protocol.auth-check.allow', 'always', chdir: @repo)
    git('remote', 'add', 'origin', 'auth-check::fixture', chdir: @repo)

    @ssh = File.join(bin, 'custom ssh')
    write_executable(@ssh, <<~RUBY)
      #!#{RbConfig.ruby}
      require 'json'
      tty = begin
        File.open('/dev/tty', 'r+') { |io| io.tty? }
      rescue SystemCallError
        false
      end
      File.open(ENV.fetch('SSH_LOG'), 'a') do |io|
        io.puts({args: ARGV, tty: tty, session: Process.getsid(0), askpass: ENV['SSH_ASKPASS'],
                 askpass_require: ENV['SSH_ASKPASS_REQUIRE']}.to_json)
      end
      exit 1
    RUBY
  end

  def teardown
    FileUtils.remove_entry(@tmp)
  end

  def write_executable(path, content)
    File.write(path, content)
    File.chmod(0o755, path)
  end

  def assert_askpass_disabled
    _out, err, status = run_multipull('-P', '2', @ws, chdir: @tmp, env: @env)
    assert_equal 1, status.exitstatus
    assert_include err, 'Failed : repo'
    assert_false File.exist?(@askpass_log), 'askpass was invoked'
  end

  def test_disables_git_askpass
    @env['GIT_ASKPASS'] = @askpass
    assert_askpass_disabled
  end

  def test_disables_configured_askpass
    git('config', 'core.askPass', @askpass, chdir: @repo)
    assert_askpass_disabled
  end

  def test_disables_ssh_askpass_fallback
    @env['SSH_ASKPASS'] = @askpass
    assert_askpass_disabled
  end

  def test_sequential_mode_keeps_askpass
    @env['GIT_ASKPASS'] = @askpass
    run_multipull(@ws, chdir: @tmp, env: @env)
    assert_path_exist @askpass_log
  end

  def assert_custom_ssh_is_non_interactive
    git('remote', 'set-url', 'origin', 'ssh://example.invalid/repo.git', chdir: @repo)
    @env['SSH_ASKPASS'] = @askpass
    output = +''
    parent_pid = nil
    PTY.spawn(GIT_ENV.merge(@env), RbConfig.ruby, '-I', LIB, EXE, '-P', '2', @ws, chdir: @tmp) do |reader, writer, pid|
      parent_pid = pid
      writer.close
      begin
        loop { output << reader.readpartial(4096) }
      rescue EOFError, Errno::EIO
        # PTYs report EOF as EIO on Linux.
      end
      Process.wait(pid)
      assert_equal 1, $?.exitstatus, output
    end
    assert_include strip_color(output), 'Failed : repo'
    calls = File.readlines(@ssh_log).map { |line| JSON.parse(line) }
    assert_not_empty calls
    calls.each do |call|
      assert_not_equal parent_pid, call['session'], 'SSH shares the parent terminal session'
      assert_false call['tty'], 'SSH still has access to the controlling terminal'
      assert_equal 'never', call['askpass_require']
      assert_equal '', call['askpass']
    end
    calls.last.fetch('args')
  end

  def test_preserves_git_ssh_command_without_terminal_access
    @env['GIT_SSH_COMMAND'] = "#{Shellwords.escape(@ssh)} -i 'key with spaces'"
    args = assert_custom_ssh_is_non_interactive
    assert_equal ['-i', 'key with spaces'], args.first(2)
  end

  def test_preserves_git_ssh_without_terminal_access
    @env['GIT_SSH'] = @ssh
    assert_include assert_custom_ssh_is_non_interactive, 'example.invalid'
  end

  def test_preserves_configured_ssh_command_without_terminal_access
    git('config', 'core.sshCommand', "#{Shellwords.escape(@ssh)} -p 2222", chdir: @repo)
    args = assert_custom_ssh_is_non_interactive
    assert_equal ['-p', '2222'], args.first(2)
  end
end
