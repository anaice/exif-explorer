# frozen_string_literal: true

require "thor"
require_relative "commands/read"
require_relative "commands/write"
require_relative "commands/remove"
require_relative "commands/copy"
require_relative "commands/stamp"

module ExifExplorer
  module CLI
    class Application < Thor
      def self.exit_on_failure?
        true
      end

      desc "read FILE", "Read EXIF metadata from an image file"
      method_option :format, aliases: "-f", type: :string, default: "table",
                             desc: "Output format: table, json, yaml"
      method_option :grouped, aliases: "-g", type: :boolean, default: false,
                              desc: "Group tags by category"
      method_option :tags, aliases: "-t", type: :array,
                           desc: "Specific tags to read"
      def read(file)
        Commands::Read.new(file, options).execute
      end

      desc "write FILE", "Write EXIF metadata to an image file"
      method_option :set, aliases: "-s", type: :array, required: true,
                          desc: "Tags to set (format: Tag=Value)"
      method_option :no_backup, type: :boolean, default: false,
                                desc: "Don't create backup file"
      def write(file)
        Commands::Write.new(file, options).execute
      end

      desc "remove FILE", "Remove EXIF metadata from an image file"
      method_option :tags, aliases: "-t", type: :array,
                           desc: "Specific tags to remove"
      method_option :all, aliases: "-a", type: :boolean, default: false,
                          desc: "Remove all EXIF data"
      method_option :no_backup, type: :boolean, default: false,
                                desc: "Don't create backup file"
      def remove(file)
        Commands::Remove.new(file, options).execute
      end

      desc "copy SOURCE DESTINATION", "Copy EXIF metadata from one file to another"
      method_option :no_backup, type: :boolean, default: false,
                                desc: "Don't create backup file"
      def copy(source, destination)
        Commands::Copy.new(source, destination, options).execute
      end

      desc "stamp FILE", "Generate a stamped image with GPS location overlay"
      method_option :output, aliases: "-o", type: :string,
                             desc: "Output file path (default: <filename>_stamped.<ext>)"
      # Visibility
      method_option :no_compass, type: :boolean, default: false,
                                 desc: "Hide compass overlay"
      method_option :no_minimap, type: :boolean, default: false,
                                 desc: "Hide mini-map overlay"
      method_option :no_info, type: :boolean, default: false,
                              desc: "Hide info text overlay"
      method_option :no_geocode, type: :boolean, default: false,
                                 desc: "Skip address lookup"
      # Minimap
      method_option :minimap_width, type: :numeric, default: 150,
                                    desc: "Mini-map width in pixels"
      method_option :minimap_height, type: :numeric, default: 150,
                                     desc: "Mini-map height in pixels"
      method_option :minimap_zoom, type: :numeric, default: 16,
                                   desc: "Mini-map zoom level (1-19)"
      method_option :minimap_opacity, type: :numeric, default: 0.75,
                                      desc: "Mini-map opacity (0.0-1.0)"
      method_option :minimap_border_radius, type: :numeric, default: 8,
                                            desc: "Mini-map corner radius"
      # Compass
      method_option :compass_width, type: :numeric, default: 90,
                                    desc: "Compass width in pixels"
      method_option :compass_height, type: :numeric, default: 90,
                                     desc: "Compass height in pixels"
      method_option :compass_arrow_color, type: :string, default: "#00d4d4",
                                          desc: "Compass arrow color (hex)"
      # Info box
      method_option :info_font_size, type: :numeric, default: 16,
                                     desc: "Info text font size"
      method_option :info_font_color, type: :string, default: "#ffffff",
                                      desc: "Info text color (hex)"
      method_option :info_bg_color, type: :string, default: "#000000",
                                    desc: "Info box background color (hex)"
      method_option :info_bg_opacity, type: :numeric, default: 0.7,
                                      desc: "Info box opacity (0.0-1.0)"
      method_option :info_border_radius, type: :numeric, default: 8,
                                         desc: "Info box corner radius"
      def stamp(file)
        Commands::Stamp.new(file, options).execute
      end

      desc "version", "Show version"
      def version
        puts "exif-explorer #{ExifExplorer::VERSION}"
      end
    end
  end
end
