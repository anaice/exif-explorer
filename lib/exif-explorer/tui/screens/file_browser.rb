# frozen_string_literal: true

require "tty-prompt"
require "pastel"

module ExifExplorer
  module TUI
    module Screens
      class FileBrowser
        SUPPORTED_EXTENSIONS = %w[.jpg .jpeg .tiff .tif .png .heic .heif .webp].freeze

        def initialize(app, mode: :file)
          @app = app
          @mode = mode
          @prompt = TTY::Prompt.new
          @pastel = Pastel.new
          @current_dir = Dir.pwd
        end

        def render
          clear_screen
          print_header

          browse_directory
        end

        private

        def clear_screen
          print "\e[2J\e[H"
        end

        def print_header
          puts @pastel.bold.cyan("File Browser")
          puts @pastel.dim("Current: #{@current_dir}")
          puts @pastel.dim("-" * 50)
          puts
        end

        def browse_directory
          entries = build_entries

          if entries.empty?
            @prompt.keypress(@pastel.yellow("No files or directories found. Press any key..."))
            @app.navigate_to(:main_menu)
            return
          end

          choice = @prompt.select(
            "Select #{@mode == :file ? 'a file' : 'a folder'}:",
            entries,
            cycle: true,
            per_page: 15,
            filter: true
          )

          handle_selection(choice)
        end

        def build_entries
          entries = []

          # Add navigation options
          entries << { name: @pastel.yellow(".. (Parent Directory)"), value: :parent }
          entries << { name: @pastel.red("<< Back to Menu"), value: :back }

          if @mode == :folder
            entries << { name: @pastel.green(">> Select This Folder"), value: :select_folder }
          end

          # Add directories
          dirs = Dir.entries(@current_dir)
                    .select { |e| File.directory?(File.join(@current_dir, e)) && !e.start_with?(".") }
                    .sort

          dirs.each do |dir|
            entries << { name: @pastel.blue("[DIR] #{dir}"), value: [:dir, dir] }
          end

          # Add image files (only in file mode)
          if @mode == :file
            files = Dir.entries(@current_dir)
                       .select { |e| image_file?(e) }
                       .sort

            files.each do |file|
              size = File.size(File.join(@current_dir, file))
              size_str = format_size(size)
              entries << { name: "#{file} (#{size_str})", value: [:file, file] }
            end
          end

          entries
        end

        def handle_selection(choice)
          case choice
          when :back
            @app.navigate_to(:main_menu)
          when :parent
            @current_dir = File.dirname(@current_dir)
            render
          when :select_folder
            process_folder
          when Array
            type, name = choice
            full_path = File.join(@current_dir, name)

            if type == :dir
              @current_dir = full_path
              render
            else
              @app.add_recent_file(full_path)
              @app.navigate_to(:exif_viewer, file: full_path)
            end
          end
        end

        def process_folder
          files = Dir.glob(File.join(@current_dir, "*"))
                     .select { |f| image_file?(f) }

          if files.empty?
            @prompt.keypress(@pastel.yellow("No image files in this folder. Press any key..."))
            render
          else
            @app.navigate_to(:batch_viewer, files: files)
          end
        end

        def image_file?(filename)
          ext = File.extname(filename).downcase
          SUPPORTED_EXTENSIONS.include?(ext)
        end

        def format_size(bytes)
          if bytes < 1024
            "#{bytes} B"
          elsif bytes < 1024 * 1024
            format("%.1f KB", bytes / 1024.0)
          else
            format("%.1f MB", bytes / (1024.0 * 1024))
          end
        end
      end
    end
  end
end
