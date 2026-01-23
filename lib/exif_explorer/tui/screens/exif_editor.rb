# frozen_string_literal: true

require "tty-prompt"
require "pastel"
require_relative "../components/exif_table"

module ExifExplorer
  module TUI
    module Screens
      class ExifEditor
        COMMON_TAGS = %w[
          Artist
          Copyright
          ImageDescription
          UserComment
          Make
          Model
          Software
          DateTimeOriginal
          CreateDate
          ModifyDate
        ].freeze

        def initialize(app, file:, exif_data:)
          @app = app
          @file = file
          @exif_data = exif_data
          @prompt = TTY::Prompt.new
          @pastel = Pastel.new
        end

        def render
          clear_screen
          print_header

          show_editor_menu
        end

        private

        def clear_screen
          print "\e[2J\e[H"
        end

        def print_header
          puts @pastel.bold.cyan("EXIF Editor")
          puts @pastel.dim("File: #{File.basename(@file)}")
          puts @pastel.dim("-" * 60)
          puts
        end

        def show_editor_menu
          choices = [
            { name: "Edit Existing Tag", value: :edit_existing },
            { name: "Add New Tag", value: :add_new },
            { name: "Remove Tag", value: :remove_tag },
            { name: "View Current EXIF", value: :view },
            { name: "Back to Viewer", value: :back }
          ]

          choice = @prompt.select("Choose an action:", choices, cycle: true)

          handle_choice(choice)
        end

        def handle_choice(choice)
          case choice
          when :edit_existing
            edit_existing_tag
          when :add_new
            add_new_tag
          when :remove_tag
            remove_tag
          when :view
            show_current_exif
          when :back
            @app.navigate_to(:exif_viewer, file: @file)
          end
        end

        def edit_existing_tag
          table = Components::ExifTable.new(@exif_data)
          tags = table.tags_for_selection

          if tags.empty?
            @prompt.keypress(@pastel.yellow("No tags to edit. Press any key..."))
            render
            return
          end

          tags << { name: @pastel.red("Cancel"), value: :cancel }

          tag = @prompt.select("Select tag to edit:", tags, cycle: true, per_page: 15, filter: true)

          if tag == :cancel
            render
          else
            edit_tag(tag)
          end
        end

        def edit_tag(tag)
          current_value = @exif_data[tag]
          puts "\n#{@pastel.cyan('Current value')}: #{current_value}"

          new_value = @prompt.ask("New value:", default: current_value.to_s)

          if new_value.nil? || new_value.empty?
            puts @pastel.yellow("Edit cancelled.")
          else
            save_tag(tag, new_value)
          end

          @prompt.keypress("Press any key to continue...")
          reload_exif
          render
        end

        def add_new_tag
          choices = COMMON_TAGS.map { |t| { name: t, value: t } }
          choices << { name: @pastel.dim("Enter custom tag..."), value: :custom }
          choices << { name: @pastel.red("Cancel"), value: :cancel }

          selection = @prompt.select("Select or enter tag name:", choices, cycle: true)

          case selection
          when :cancel
            render
          when :custom
            tag = @prompt.ask("Enter tag name:")
            if tag && !tag.empty?
              add_value_for_tag(tag)
            else
              render
            end
          else
            add_value_for_tag(selection)
          end
        end

        def add_value_for_tag(tag)
          value = @prompt.ask("Enter value for #{@pastel.cyan(tag)}:")

          if value && !value.empty?
            save_tag(tag, value)
          else
            puts @pastel.yellow("No value provided, tag not added.")
          end

          @prompt.keypress("Press any key to continue...")
          reload_exif
          render
        end

        def remove_tag
          table = Components::ExifTable.new(@exif_data)
          tags = table.tags_for_selection

          if tags.empty?
            @prompt.keypress(@pastel.yellow("No tags to remove. Press any key..."))
            render
            return
          end

          tags << { name: @pastel.red("Cancel"), value: :cancel }

          tag = @prompt.select("Select tag to remove:", tags, cycle: true, per_page: 15, filter: true)

          if tag == :cancel
            render
          elsif @prompt.yes?("Remove #{@pastel.cyan(tag)}?")
            begin
              writer = Core::Writer.new(@file)
              writer.remove_tags(tag)
              puts @pastel.green("Tag removed successfully!")
            rescue ExifExplorer::Error => e
              puts @pastel.red("Error: #{e.message}")
            end

            @prompt.keypress("Press any key to continue...")
            reload_exif
            render
          else
            render
          end
        end

        def save_tag(tag, value)
          writer = Core::Writer.new(@file)
          writer.write(tag => value)
          puts @pastel.green("Tag saved successfully!")
        rescue ExifExplorer::Error => e
          puts @pastel.red("Error: #{e.message}")
        end

        def show_current_exif
          clear_screen
          print_header

          table = Components::ExifTable.new(@exif_data)
          puts table.render_grouped

          @prompt.keypress("\nPress any key to continue...")
          render
        end

        def reload_exif
          @exif_data = ExifExplorer.read(@file)
        rescue ExifExplorer::Error
          # Keep existing data if reload fails
        end
      end
    end
  end
end
