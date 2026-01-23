# frozen_string_literal: true

require "tty-box"
require "pastel"

module ExifExplorer
  module TUI
    module Components
      class Header
        def initialize(title: "EXIF Explorer")
          @title = title
          @pastel = Pastel.new
        end

        def render(width: 80)
          TTY::Box.frame(
            @pastel.bold.cyan(@title),
            width: width,
            align: :center,
            padding: [0, 1],
            border: :thick
          )
        end
      end
    end
  end
end
