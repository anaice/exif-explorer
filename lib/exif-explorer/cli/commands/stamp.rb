# frozen_string_literal: true

require "pastel"

module ExifExplorer
  module CLI
    module Commands
      class Stamp
        def initialize(file, options)
          @file = file
          @options = options
          @pastel = Pastel.new
        end

        def execute
          puts @pastel.cyan("Generating stamped image for: #{File.basename(@file)}")

          stamper_options = build_stamper_options

          stamper = Core::ImageStamper.new(@file, stamper_options)
          coords = stamper.exif_data.gps_coordinates

          puts @pastel.dim("Location: #{coords[:latitude]}, #{coords[:longitude]}")

          if stamper.exif_data.has_image_direction?
            direction = stamper.exif_data.image_direction
            puts @pastel.dim("Direction: #{direction[:degrees]}° #{direction[:cardinal]}")
          end

          puts @pastel.dim("Fetching map tiles...")

          if stamper_options[:geocode]
            puts @pastel.dim("Looking up address...")
          end

          output_path = @options[:output]
          result = stamper.stamp(output_path)

          puts @pastel.green("Stamped image generated successfully!")
          puts "  #{@pastel.cyan("Output")}: #{result}"
        rescue NoGPSDataError => e
          puts @pastel.red("Error: No GPS data found in image")
          puts @pastel.dim("The image must contain GPSLatitude and GPSLongitude EXIF tags")
          exit 1
        rescue TileFetchError => e
          puts @pastel.red("Error: Failed to fetch map tiles")
          puts @pastel.dim("Check your internet connection")
          puts @pastel.dim(e.message)
          exit 1
        rescue GeocodingError => e
          puts @pastel.yellow("Warning: Could not fetch address")
          puts @pastel.dim(e.message)
        rescue FileNotFoundError => e
          puts @pastel.red("Error: #{e.message}")
          exit 1
        rescue ImageStampError, StandardError => e
          puts @pastel.red("Error: #{e.message}")
          exit 1
        end

        private

        def build_stamper_options
          opts = {}

          # Visibility options
          opts[:show_compass] = !@options[:no_compass] if @options.key?(:no_compass)
          opts[:show_minimap] = !@options[:no_minimap] if @options.key?(:no_minimap)
          opts[:show_info] = !@options[:no_info] if @options.key?(:no_info)
          opts[:geocode] = !@options[:no_geocode] if @options.key?(:no_geocode)
          opts[:geocoder] = @options[:geocoder].to_sym if @options[:geocoder]

          # Minimap options
          opts[:minimap_width] = @options[:minimap_width].to_i if @options[:minimap_width]
          opts[:minimap_height] = @options[:minimap_height].to_i if @options[:minimap_height]
          opts[:minimap_zoom] = @options[:minimap_zoom].to_i if @options[:minimap_zoom]
          opts[:minimap_opacity] = @options[:minimap_opacity].to_f if @options[:minimap_opacity]
          opts[:minimap_border_radius] = @options[:minimap_border_radius].to_i if @options[:minimap_border_radius]

          # Compass options
          opts[:compass_width] = @options[:compass_width].to_i if @options[:compass_width]
          opts[:compass_height] = @options[:compass_height].to_i if @options[:compass_height]
          opts[:compass_arrow_color] = @options[:compass_arrow_color] if @options[:compass_arrow_color]

          # Info box options
          opts[:info_font_size] = @options[:info_font_size].to_i if @options[:info_font_size]
          opts[:info_font_color] = @options[:info_font_color] if @options[:info_font_color]
          opts[:info_bg_color] = @options[:info_bg_color] if @options[:info_bg_color]
          opts[:info_bg_opacity] = @options[:info_bg_opacity].to_f if @options[:info_bg_opacity]
          opts[:info_border_radius] = @options[:info_border_radius].to_i if @options[:info_border_radius]

          opts
        end
      end
    end
  end
end
