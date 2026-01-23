# frozen_string_literal: true

require "pastel"

module ExifExplorer
  module CLI
    module Commands
      class Write
        def initialize(file, options)
          @file = file
          @options = options
          @pastel = Pastel.new
        end

        def execute
          ExifExplorer.configuration.backup_original = !@options[:no_backup]

          tags = parse_tags
          if tags.empty?
            puts @pastel.yellow("No valid tags provided.")
            exit 1
          end

          ExifExplorer.write(@file, tags)

          puts @pastel.green("Successfully updated #{tags.size} tag(s):")
          tags.each do |tag, value|
            puts "  #{@pastel.cyan(tag)}: #{value}"
          end
        rescue ExifExplorer::Error => e
          puts @pastel.red("Error: #{e.message}")
          exit 1
        end

        private

        def parse_tags
          tags = {}
          @options[:set].each do |assignment|
            if assignment.include?("=")
              tag, value = assignment.split("=", 2)
              tags[tag.strip] = value.strip
            else
              puts @pastel.yellow("Warning: Invalid format '#{assignment}', expected 'Tag=Value'")
            end
          end
          tags
        end
      end
    end
  end
end
