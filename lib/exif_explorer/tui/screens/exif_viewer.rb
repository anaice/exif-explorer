# frozen_string_literal: true

require "tty-prompt"
require "pastel"
require_relative "../components/exif_table"

module ExifExplorer
  module TUI
    module Screens
      class ExifViewer
        def initialize(app, file:)
          @app = app
          @file = file
          @prompt = TTY::Prompt.new
          @pastel = Pastel.new
          @exif_data = nil
        end

        def render
          clear_screen
          print_header

          load_exif_data

          if @exif_data.nil? || @exif_data.empty?
            puts @pastel.yellow("No EXIF data found in this file.")
          else
            display_exif
          end

          show_actions
        end

        private

        def clear_screen
          print "\e[2J\e[H"
        end

        def print_header
          puts @pastel.bold.cyan("EXIF Viewer")
          puts @pastel.dim("File: #{File.basename(@file)}")
          puts @pastel.dim("Path: #{@file}")
          puts @pastel.dim("-" * 60)
        end

        def load_exif_data
          @exif_data = ExifExplorer.read(@file)
        rescue ExifExplorer::Error => e
          puts @pastel.red("Error: #{e.message}")
          @exif_data = nil
        end

        def display_exif
          table = Components::ExifTable.new(@exif_data)
          puts table.render_grouped
          puts
        end

        def show_actions
          choices = []

          if @exif_data && !@exif_data.empty?
            choices << { name: "Edit Tags", value: :edit }
            choices << { name: "Export to JSON", value: :export_json }
            choices << { name: "Export to YAML", value: :export_yaml }
            choices << { name: "Remove All EXIF", value: :remove_all }
          end

          choices << { name: "Open Another File", value: :browse }
          choices << { name: "Back to Menu", value: :back }

          choice = @prompt.select("\nActions:", choices, cycle: true)

          handle_action(choice)
        end

        def handle_action(choice)
          case choice
          when :edit
            @app.navigate_to(:exif_editor, file: @file, exif_data: @exif_data)
          when :export_json
            export_to_file(:json)
          when :export_yaml
            export_to_file(:yaml)
          when :remove_all
            confirm_remove_all
          when :browse
            @app.navigate_to(:file_browser, mode: :file)
          when :back
            @app.navigate_to(:main_menu)
          end
        end

        def export_to_file(format)
          ext = format == :json ? ".json" : ".yaml"
          default_name = File.basename(@file, ".*") + "_exif" + ext

          filename = @prompt.ask("Save as:", default: default_name)
          return render if filename.nil?

          content = case format
                    when :json
                      Formatters::JsonFormatter.new(@exif_data).format_grouped
                    when :yaml
                      Formatters::YamlFormatter.new(@exif_data).format_grouped
                    end

          File.write(filename, content)
          puts @pastel.green("Exported to: #{filename}")
          @prompt.keypress("Press any key to continue...")
          render
        end

        def confirm_remove_all
          if @prompt.yes?(@pastel.red("Are you sure you want to remove ALL EXIF data?"))
            begin
              writer = Core::Writer.new(@file)
              writer.remove_all_exif
              puts @pastel.green("All EXIF data removed successfully!")
            rescue ExifExplorer::Error => e
              puts @pastel.red("Error: #{e.message}")
            end

            @prompt.keypress("Press any key to continue...")
          end

          render
        end
      end
    end
  end
end
