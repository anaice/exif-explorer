# frozen_string_literal: true

module ExifExplorer
  module Core
    class ExifData
      CAMERA_TAGS = %w[Make Model LensModel LensInfo Software].freeze
      EXPOSURE_TAGS = %w[ExposureTime FNumber ISO ShutterSpeedValue ApertureValue ExposureCompensation ExposureMode MeteringMode Flash WhiteBalance].freeze
      GPS_TAGS = %w[GPSLatitude GPSLongitude GPSAltitude GPSLatitudeRef GPSLongitudeRef GPSAltitudeRef GPSTimeStamp GPSDateStamp GPSImgDirection GPSImgDirectionRef].freeze
      DATETIME_TAGS = %w[DateTimeOriginal CreateDate ModifyDate DateTimeDigitized].freeze
      IMAGE_TAGS = %w[ImageWidth ImageHeight Orientation ColorSpace FileType FileSize MIMEType].freeze

      attr_reader :file_path, :raw_data

      def initialize(file_path, raw_data)
        @file_path = file_path
        @raw_data = raw_data.to_h
      end

      def [](tag)
        @raw_data[tag.to_s] || @raw_data[tag.to_sym]
      end

      def camera
        extract_group(CAMERA_TAGS)
      end

      def exposure
        extract_group(EXPOSURE_TAGS)
      end

      def gps
        extract_group(GPS_TAGS)
      end

      def datetime
        extract_group(DATETIME_TAGS)
      end

      def image
        extract_group(IMAGE_TAGS)
      end

      def all_tags
        @raw_data.keys.sort
      end

      def grouped
        {
          camera: camera,
          exposure: exposure,
          gps: gps,
          datetime: datetime,
          image: image,
          other: other_tags
        }
      end

      def to_h
        @raw_data.dup
      end

      def to_json(*args)
        require "json"
        @raw_data.to_json(*args)
      end

      def to_yaml
        require "yaml"
        @raw_data.to_yaml
      end

      def empty?
        @raw_data.empty?
      end

      def has_gps?
        !self["GPSLatitude"].nil? && !self["GPSLongitude"].nil?
      end

      def gps_coordinates
        return nil unless has_gps?

        lat = parse_coordinate(self["GPSLatitude"])
        lon = parse_coordinate(self["GPSLongitude"])
        lat_ref = self["GPSLatitudeRef"] || "N"
        lon_ref = self["GPSLongitudeRef"] || "E"

        lat = -lat if lat_ref.to_s.start_with?("S")
        lon = -lon if lon_ref.to_s.start_with?("W")

        { latitude: lat.round(6), longitude: lon.round(6) }
      end

      def google_maps_url
        coords = gps_coordinates
        return nil unless coords

        "https://www.google.com/maps?q=#{coords[:latitude]},#{coords[:longitude]}"
      end

      def has_image_direction?
        !self["GPSImgDirection"].nil?
      end

      def image_direction
        return nil unless has_image_direction?

        direction = self["GPSImgDirection"].to_f.round(2)
        reference = self["GPSImgDirectionRef"]

        ref_label = case reference.to_s.upcase
                    when "T", "TRUE NORTH" then "True North"
                    when "M", "MAGNETIC NORTH" then "Magnetic North"
                    else reference.to_s
                    end

        { degrees: direction, reference: ref_label, cardinal: degrees_to_cardinal(direction) }
      end

      private

      def degrees_to_cardinal(degrees)
        directions = %w[N NNE NE ENE E ESE SE SSE S SSW SW WSW W WNW NW NNW]
        index = ((degrees + 11.25) / 22.5).to_i % 16
        directions[index]
      end

      def parse_coordinate(value)
        return value.to_f if value.is_a?(Numeric)

        # Parse DMS format: "25 deg 24' 31.00" S" or "25 deg 24' 31.00""
        str = value.to_s

        # Try to match DMS pattern
        if str =~ /(\d+)\s*deg\s*(\d+)'\s*([\d.]+)"/i
          degrees = $1.to_f
          minutes = $2.to_f
          seconds = $3.to_f
          degrees + (minutes / 60.0) + (seconds / 3600.0)
        elsif str =~ /^-?[\d.]+$/
          str.to_f
        else
          0.0
        end
      end

      def extract_group(tags)
        result = {}
        tags.each do |tag|
          value = @raw_data[tag]
          result[tag] = value unless value.nil?
        end
        result
      end

      def other_tags
        known_tags = CAMERA_TAGS + EXPOSURE_TAGS + GPS_TAGS + DATETIME_TAGS + IMAGE_TAGS
        @raw_data.reject { |k, _| known_tags.include?(k.to_s) }
      end
    end
  end
end
