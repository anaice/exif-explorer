# frozen_string_literal: true

require "pastel"

module ExifExplorer
  module CLI
    module Commands
      class Copy
        def initialize(source, destination, options)
          @source = source
          @destination = destination
          @options = options
          @pastel = Pastel.new
        end

        def execute
          ExifExplorer.configuration.backup_original = !@options[:no_backup]

          writer = Core::Writer.new(@destination)
          writer.copy_from(@source)

          puts @pastel.green("Successfully copied EXIF data:")
          puts "  #{@pastel.cyan('From')}: #{@source}"
          puts "  #{@pastel.cyan('To')}:   #{@destination}"
        rescue ExifExplorer::Error => e
          puts @pastel.red("Error: #{e.message}")
          exit 1
        end
      end
    end
  end
end
