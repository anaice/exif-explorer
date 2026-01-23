# frozen_string_literal: true

require "pastel"

module ExifExplorer
  module TUI
    module Components
      class Footer
        def initialize(hints: [])
          @hints = hints
          @pastel = Pastel.new
        end

        def render
          hint_text = @hints.map { |h| @pastel.dim(h) }.join("  |  ")
          "\n#{hint_text}\n"
        end
      end
    end
  end
end
