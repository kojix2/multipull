# frozen_string_literal: true

require_relative 'test_helper'

# Runs exe/multipull against real git repositories created in a temporary directory.
class TestPull < Minitest::Test
  include MultipullTestHelper

  def setup
    @tmp = Dir.mktmpdir('multipull-test')
    @remote = File.join(@tmp, 'remote.git')
    @ws = File.join(@tmp, 'ws')

    git('init', '-q', '--bare', '-b', 'main', @remote, chdir: @tmp)
    seed = File.join(@tmp, 'seed')
    git('init', '-q', '-b', 'main', seed, chdir: @tmp)
    git('commit', '-q', '--allow-empty', '-m', 'first', chdir: seed)
    git('push', '-q', @remote, 'main', chdir: seed)

    FileUtils.mkdir_p(File.join(@ws, 'notrepo'))
    %w[a b].each { |name| git('clone', '-q', @remote, File.join(@ws, name), chdir: @tmp) }

    git('commit', '-q', '--allow-empty', '-m', 'second', chdir: seed)
    git('push', '-q', @remote, 'main', chdir: seed)
    @latest = git('rev-parse', 'HEAD', chdir: seed)
  end

  def teardown
    FileUtils.remove_entry(@tmp)
  end

  def head(name)
    git('rev-parse', 'HEAD', chdir: File.join(@ws, name))
  end

  def test_pulls_repositories_and_skips_others
    _out, err, status = run_multipull('ws', chdir: @tmp)

    assert status.success?, err
    assert_equal @latest, head('a')
    assert_equal @latest, head('b')
    assert_includes err, 'Skipped : notrepo'
    assert_includes err, 'Succeeded : a b'
  end

  def test_pulls_in_parallel
    _out, err, status = run_multipull('-P', '2', 'ws', chdir: @tmp)

    assert status.success?, err
    assert_equal @latest, head('a')
    assert_equal @latest, head('b')
    assert_includes err, 'Succeeded : a b'
  end

  def test_pulls_worktree_whose_dot_git_is_a_file
    git('worktree', 'add', '-q', '-b', 'wt', File.join(@ws, 'wt'), 'origin/main', chdir: File.join(@ws, 'a'))
    assert File.file?(File.join(@ws, 'wt', '.git'))

    _out, err, status = run_multipull('ws', chdir: @tmp)

    assert status.success?, err
    assert_equal @latest, head('wt')
    assert_includes err, 'Succeeded : a b wt'
  end

  def test_exits_with_failure_when_a_pull_fails
    git('remote', 'set-url', 'origin', File.join(@tmp, 'nonexistent.git'), chdir: File.join(@ws, 'b'))

    [[], %w[-P 2]].each do |opts|
      _out, err, status = run_multipull(*opts, 'ws', chdir: @tmp)

      assert_equal 1, status.exitstatus
      assert_includes err, 'Succeeded : a'
      assert_includes err, 'Failed : b'
    end
  end

  def test_exits_with_failure_for_missing_directory
    out, _err, status = run_multipull('nosuchdir', chdir: @tmp)

    assert_equal 1, status.exitstatus
    assert_includes out, 'nosuchdir is not a directory'
  end

  def test_git_arguments_are_not_interpreted_by_shell
    run_multipull('--ff-only;touch INJECTED', 'ws', chdir: @tmp)

    assert_empty Dir.glob('**/INJECTED', base: @tmp)
  end
end
