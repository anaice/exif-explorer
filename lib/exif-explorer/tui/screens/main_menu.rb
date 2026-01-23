# frozen_string_literal: true

require "tty-prompt"
require "pastel"

module ExifExplorer
  module TUI
    module Screens
      class MainMenu
        MENU_OPTIONS = [
          { name: "Open File", value: :open_file },
          { name: "Open Folder", value: :open_folder },
          { name: "Recent Files", value: :recent },
          { name: "Settings", value: :settings },
          { name: "Exit", value: :exit }
        ].freeze

        def initialize(app)
          @app = app
          @prompt = TTY::Prompt.new
          @pastel = Pastel.new
        end

        def render
          clear_screen
          print_header

          choice = @prompt.select("What would you like to do?", MENU_OPTIONS, cycle: true)

          handle_choice(choice)
        end

        private

        def clear_screen
          print "\e[2J\e[H"
        end

        def print_header
          puts @pastel.bold.cyan("=" * 50)
          puts @pastel.bold.cyan("        EXIF Explorer v#{ExifExplorer::VERSION}")
          puts @pastel.bold.cyan("=" * 50)
          puts
        end

        def handle_choice(choice)
          case choice
          when :open_file
            @app.navigate_to(:file_browser, mode: :file)
          when :open_folder
            @app.navigate_to(:file_browser, mode: :folder)
          when :recent
            show_recent_files
          when :settings
            show_settings
          when :exit
            @app.quit
          end
        end

        def show_recent_files
          recent = @app.recent_files

          if recent.empty?
            @prompt.keypress(@pastel.yellow("No recent files. Press any key to continue..."))
            render
          else
            choices = recent.map { |f| { name: File.basename(f), value: f } }
            choices << { name: "Back", value: :back }

            file = @prompt.select("Recent files:", choices, cycle: true)

            if file == :back
              render
            else
              @app.navigate_to(:exif_viewer, file: file)
            end
          end
        end

        def show_settings
          backup_status = ExifExplorer.configuration.backup_original ? "ON" : "OFF"

          choices = [
            { name: "Backup originals: #{backup_status}", value: :toggle_backup },
            { name: "Back", value: :back }
          ]

          choice = @prompt.select("Settings:", choices)

          case choice
          when :toggle_backup
            ExifExplorer.configuration.backup_original = !ExifExplorer.configuration.backup_original
            show_settings
          when :back
            render
          end
        end
      end
    end
  end
end
