# frozen_string_literal: true

require "tty-cursor"
require "pastel"
require_relative "screens/main_menu"
require_relative "screens/file_browser"
require_relative "screens/exif_viewer"
require_relative "screens/exif_editor"
require_relative "components/header"
require_relative "components/footer"
require_relative "components/exif_table"

module ExifExplorer
  module TUI
    class Application
      MAX_RECENT_FILES = 10

      attr_reader :recent_files

      def initialize
        @cursor = TTY::Cursor
        @pastel = Pastel.new
        @running = false
        @current_screen = nil
        @recent_files = []
        @screen_params = {}
      end

      def run
        @running = true
        setup_signal_handlers

        navigate_to(:main_menu)

        while @running
          render_current_screen
        end

        cleanup
      end

      def quit
        @running = false
      end

      def navigate_to(screen, **params)
        @current_screen = screen
        @screen_params = params
      end

      def add_recent_file(file_path)
        @recent_files.delete(file_path)
        @recent_files.unshift(file_path)
        @recent_files = @recent_files.take(MAX_RECENT_FILES)
      end

      private

      def render_current_screen
        screen = build_screen(@current_screen)
        screen.render
      rescue Interrupt
        quit
      rescue StandardError => e
        handle_error(e)
      end

      def build_screen(screen_name)
        case screen_name
        when :main_menu
          Screens::MainMenu.new(self)
        when :file_browser
          Screens::FileBrowser.new(self, **@screen_params)
        when :exif_viewer
          Screens::ExifViewer.new(self, **@screen_params)
        when :exif_editor
          Screens::ExifEditor.new(self, **@screen_params)
        else
          Screens::MainMenu.new(self)
        end
      end

      def setup_signal_handlers
        Signal.trap("INT") { quit }
        Signal.trap("TERM") { quit }
      rescue ArgumentError
        # Signal not supported on this platform
      end

      def cleanup
        print @cursor.show
        print @cursor.clear_screen
        puts @pastel.cyan("Goodbye!")
      end

      def handle_error(error)
        print @cursor.clear_screen
        puts @pastel.red("An error occurred: #{error.message}")
        puts @pastel.dim(error.backtrace.first(5).join("\n")) if error.backtrace

        prompt = TTY::Prompt.new
        choice = prompt.select("What would you like to do?", [
          { name: "Return to Main Menu", value: :menu },
          { name: "Exit", value: :exit }
        ])

        case choice
        when :menu
          navigate_to(:main_menu)
        when :exit
          quit
        end
      end
    end
  end
end
