# frozen_string_literal: true

require "pastel"

module ExifExplorer
  module CLI
    module Commands
      class Remove
        def initialize(file, options)
          @file = file
          @options = options
          @pastel = Pastel.new
        end

        def execute
          ExifExplorer.configuration.backup_original = !@options[:no_backup]

          writer = Core::Writer.new(@file)

          if @options[:all]
            remove_all(writer)
          elsif @options[:tags]&.any?
            remove_specific(writer)
          else
            puts @pastel.yellow("Please specify --tags or --all")
            exit 1
          end
        rescue ExifExplorer::Error => e
          puts @pastel.red("Error: #{e.message}")
          exit 1
        end

        private

        def remove_all(writer)
          writer.remove_all_exif
          puts @pastel.green("Successfully removed all EXIF data from #{@file}")
        end

        def remove_specific(writer)
          writer.remove_tags(*@options[:tags])
          puts @pastel.green("Successfully removed #{@options[:tags].size} tag(s):")
          @options[:tags].each do |tag|
            puts "  #{@pastel.dim('-')} #{tag}"
          end
        end
      end
    end
  end
end
