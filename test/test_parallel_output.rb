# frozen_string_literal: true

require_relative 'test_helper'

# Uses a fake git that writes output slowly, so that output from concurrently
# running pulls would interleave if it were not buffered.
class TestParallelOutput < Test::Unit::TestCase
  include MultipullTestHelper

  FAKE_GIT = <<~SH
    #!/bin/sh
    [ "$1" = pull ] || exit 1
    name=$(basename "$PWD")
    echo "$name begin"
    touch "$RUN_DIR/$name"
    sleep 0.3
    ls "$RUN_DIR" | wc -l >> "$CONCURRENCY_LOG"
    echo "$name prompt=$GIT_TERMINAL_PROMPT"
    rm "$RUN_DIR/$name"
    echo "$name end" >&2
    case "$name" in fail*) exit 1;; esac
    exit 0
  SH

  REPOS = %w[fail1 r1 r2 r3 r4 r5].freeze

  def setup
    @tmp = Dir.mktmpdir('multipull-test')
    bin = File.join(@tmp, 'bin')
    FileUtils.mkdir_p(bin)
    File.write(File.join(bin, 'git'), FAKE_GIT)
    File.chmod(0o755, File.join(bin, 'git'))

    @ws = File.join(@tmp, 'ws')
    REPOS.each { |name| FileUtils.mkdir_p(File.join(@ws, name, '.git')) }
    @run_dir = File.join(@tmp, 'running')
    FileUtils.mkdir_p(@run_dir)
    @concurrency_log = File.join(@tmp, 'concurrency.log')

    @env = {
      'PATH' => "#{bin}#{File::PATH_SEPARATOR}#{ENV.fetch('PATH')}",
      'RUN_DIR' => @run_dir,
      'CONCURRENCY_LOG' => @concurrency_log
    }
  end

  def teardown
    FileUtils.remove_entry(@tmp)
  end

  def test_output_of_each_repository_is_not_interleaved
    out, err, status = run_multipull('-P', '3', 'ws', chdir: @tmp, env: @env)

    assert_equal 1, status.exitstatus
    assert_include err, 'Succeeded : r1 r2 r3 r4 r5'
    assert_include err, 'Failed : fail1'
    assert_operator File.readlines(@concurrency_log).map(&:to_i).max, :>, 1, 'pulls did not run concurrently'

    blocks = out.lines(chomp: true).drop(1).each_slice(4).to_a
    assert_equal REPOS.sort, blocks.map(&:first).sort
    blocks.each do |name, *body|
      assert_equal ["#{name} begin", "#{name} prompt=0", "#{name} end"], body
    end
  end
end
