# frozen_string_literal: true

module Multipull
  module TerminalColor
    def bold(s)
      "\e[1m#{s}\e[22m"
    end

    def cyan(s)
      "\e[36m#{s}\e[0m"
    end

    def blue(s)
      "\e[34m#{s}\e[0m"
    end
  end
end
