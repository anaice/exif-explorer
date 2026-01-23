# frozen_string_literal: true

require "pastel"

module ExifExplorer
  module CLI
    module Commands
      class Read
        def initialize(file, options)
          @file = file
          @options = options
          @pastel = Pastel.new
        end

        def execute
          exif_data = ExifExplorer.read(@file)

          if @options[:tags]
            display_specific_tags(exif_data)
          else
            display_all(exif_data)
          end
        rescue ExifExplorer::Error => e
          puts @pastel.red("Error: #{e.message}")
          exit 1
        end

        private

        def display_all(exif_data)
          formatter = create_formatter(exif_data)

          if @options[:grouped]
            puts formatter.format_grouped
          else
            puts formatter.format
          end
        end

        def display_specific_tags(exif_data)
          @options[:tags].each do |tag|
            value = exif_data[tag]
            if value
              puts "#{@pastel.cyan(tag)}: #{value}"
            else
              puts "#{@pastel.cyan(tag)}: #{@pastel.dim('(not found)')}"
            end
          end
        end

        def create_formatter(exif_data)
          case @options[:format].to_s.downcase
          when "json"
            Formatters::JsonFormatter.new(exif_data)
          when "yaml"
            Formatters::YamlFormatter.new(exif_data)
          else
            Formatters::TableFormatter.new(exif_data)
          end
        end
      end
    end
  end
end
