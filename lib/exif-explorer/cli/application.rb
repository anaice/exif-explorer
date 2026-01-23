# frozen_string_literal: true

require "thor"
require_relative "commands/read"
require_relative "commands/write"
require_relative "commands/remove"
require_relative "commands/copy"

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

      desc "version", "Show version"
      def version
        puts "exif-explorer #{ExifExplorer::VERSION}"
      end
    end
  end
end
