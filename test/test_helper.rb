# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path('../lib', __dir__)
require 'multipull'

require 'fileutils'
require 'open3'
require 'rbconfig'
require 'stringio'
require 'tmpdir'
require 'test/unit'

module MultipullTestHelper
  EXE = File.expand_path('../exe/multipull', __dir__)
  LIB = File.expand_path('../lib', __dir__)

  # Isolate git from the user's configuration.
  GIT_ENV = {
    'GIT_CONFIG_GLOBAL' => File::NULL,
    'GIT_CONFIG_NOSYSTEM' => '1',
    'GIT_AUTHOR_NAME' => 'test',
    'GIT_AUTHOR_EMAIL' => 'test@example.com',
    'GIT_COMMITTER_NAME' => 'test',
    'GIT_COMMITTER_EMAIL' => 'test@example.com'
  }.freeze

  def run_multipull(*args, chdir:, env: {})
    out, err, status = Open3.capture3(GIT_ENV.merge(env), RbConfig.ruby, '-I', LIB, EXE, *args, chdir: chdir)
    [strip_color(out), strip_color(err), status]
  end

  def git(*args, chdir:)
    out, status = Open3.capture2e(GIT_ENV, 'git', *args, chdir: chdir)
    raise "git #{args.join(' ')} failed:\n#{out}" unless status.success?

    out.strip
  end

  def strip_color(str)
    str.gsub(/\e\[\d+m/, '')
  end
end
