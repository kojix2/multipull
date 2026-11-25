# frozen_string_literal: true

require_relative 'test_helper'

class TestOptions < Test::Unit::TestCase
  def parse(*argv)
    cmd = Multipull::Command.new
    cmd.send(:parse_options, argv)
    {
      dirs: cmd.instance_variable_get(:@dirs),
      git_opts: cmd.instance_variable_get(:@git_opts),
      jobs: cmd.instance_variable_get(:@jobs)
    }
  end

  def assert_exits_with_error(*argv)
    stderr = $stderr
    $stderr = StringIO.new
    e = assert_raise(SystemExit) { parse(*argv) }
    assert_equal 1, e.status
    assert_match(/\Amultipull: /, $stderr.string)
  ensure
    $stderr = stderr
  end

  def test_defaults
    assert_equal({ dirs: ['.'], git_opts: [], jobs: 1 }, parse)
  end

  def test_unknown_options_are_passed_to_git
    assert_equal({ dirs: ['ws'], git_opts: ['--ff-only'], jobs: 1 }, parse('--ff-only', 'ws'))
  end

  def test_short_v_is_not_expanded_to_version
    assert_equal ['-v'], parse('-v')[:git_opts]
  end

  def test_arguments_after_double_dash_are_passed_to_git
    assert_equal({ dirs: ['ws'], git_opts: %w[-X ours], jobs: 1 }, parse('ws', '--', '-X', 'ours'))
  end

  def test_parallel
    assert_equal 4, parse('-P', '4')[:jobs]
    assert_equal 3, parse('--parallel=3')[:jobs]
    assert_equal 2, parse('-P2', 'ws')[:jobs]
  end

  def test_parallel_after_double_dash_is_passed_to_git
    assert_equal({ dirs: ['ws'], git_opts: %w[-P 2], jobs: 1 }, parse('ws', '--', '-P', '2'))
  end

  def test_invalid_parallel
    assert_exits_with_error('-P', '0')
    assert_exits_with_error('-P', 'abc')
    assert_exits_with_error('-P')
  end
end
