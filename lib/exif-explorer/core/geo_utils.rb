# frozen_string_literal: true

module ExifExplorer
  module Core
    module GeoUtils
      TILE_SIZE = 256
      CARDINALS = %w[N NNE NE ENE E ESE SE SSE S SSW SW WSW W WNW NW NNW].freeze

      module_function

      # Convert latitude/longitude to tile coordinates at given zoom level
      # Uses Web Mercator projection (EPSG:3857)
      def lat_lng_to_tile(lat, lng, zoom)
        n = 2**zoom
        x = ((lng + 180.0) / 360.0 * n).floor
        lat_rad = lat * Math::PI / 180.0
        y = ((1.0 - Math.log(Math.tan(lat_rad) + 1.0 / Math.cos(lat_rad)) / Math::PI) / 2.0 * n).floor

        { x: x, y: y }
      end

      # Get fractional tile coordinates for precise pixel positioning
      def lat_lng_to_tile_fraction(lat, lng, zoom)
        n = 2**zoom
        x = (lng + 180.0) / 360.0 * n
        lat_rad = lat * Math::PI / 180.0
        y = (1.0 - Math.log(Math.tan(lat_rad) + 1.0 / Math.cos(lat_rad)) / Math::PI) / 2.0 * n

        { x: x, y: y }
      end

      # Convert degrees to cardinal direction (N, NE, E, SE, S, SW, W, NW, etc.)
      def degrees_to_cardinal(degrees)
        normalized = degrees % 360
        index = ((normalized + 11.25) / 22.5).to_i % 16
        CARDINALS[index]
      end

      # Format direction as "135° SE"
      def format_direction(degrees)
        return nil if degrees.nil?

        cardinal = degrees_to_cardinal(degrees)
        "#{format('%.2f', degrees)}° #{cardinal}"
      end

      # Calculate pixel offset within a tile for given coordinates
      def pixel_offset_in_tile(lat, lng, zoom)
        fraction = lat_lng_to_tile_fraction(lat, lng, zoom)
        tile = lat_lng_to_tile(lat, lng, zoom)

        {
          x: ((fraction[:x] - tile[:x]) * TILE_SIZE).round,
          y: ((fraction[:y] - tile[:y]) * TILE_SIZE).round
        }
      end

      # Format date for display (Brazilian format)
      def format_datetime(datetime)
        return nil if datetime.nil?

        # Handle Time objects directly
        if datetime.is_a?(Time)
          months_pt = %w[jan fev mar abr mai jun jul ago set out nov dez]
          month_name = months_pt[datetime.month - 1]
          day = datetime.day.to_s.rjust(2, "0")
          hour = datetime.hour.to_s.rjust(2, "0")
          min = datetime.min.to_s.rjust(2, "0")
          sec = datetime.sec.to_s.rjust(2, "0")
          return "#{day} de #{month_name} de #{datetime.year} #{hour}:#{min}:#{sec}"
        end

        datetime_str = datetime.to_s
        return nil if datetime_str.empty?

        # EXIF format: "2025:01:15 23:49:08"
        if datetime_str =~ /(\d{4}):(\d{2}):(\d{2})\s+(\d{2}):(\d{2}):(\d{2})/
          year, month, day, hour, min, sec = $1, $2, $3, $4, $5, $6
          months_pt = %w[jan fev mar abr mai jun jul ago set out nov dez]
          month_name = months_pt[month.to_i - 1]
          "#{day} de #{month_name} de #{year} #{hour}:#{min}:#{sec}"
        else
          datetime_str
        end
      end
    end
  end
end
