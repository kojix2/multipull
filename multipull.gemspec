# frozen_string_literal: true

require_relative 'lib/multipull/version'

Gem::Specification.new do |spec|
  spec.name          = 'multipull'
  spec.version       = Multipull::VERSION
  spec.authors       = ['kojix2']
  spec.email         = ['2xijok@gmail.com']

  spec.summary       = 'Git pull multiple repositories at once'
  spec.description   = 'Git pull multiple repositories at once'
  spec.homepage      = 'https://github.com/kojix2/multipull'
  spec.license       = 'MIT'

  spec.files         = Dir['*.{md,txt}', '{lib,exe}/**/*']
  spec.bindir        = 'exe'
  spec.executables   = 'multipull'
  spec.require_paths = ['lib']
end
