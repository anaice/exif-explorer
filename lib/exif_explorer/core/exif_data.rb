# frozen_string_literal: true

module ExifExplorer
  module Core
    class ExifData
      CAMERA_TAGS = %w[Make Model LensModel LensInfo Software].freeze
      EXPOSURE_TAGS = %w[ExposureTime FNumber ISO ShutterSpeedValue ApertureValue ExposureCompensation ExposureMode MeteringMode Flash WhiteBalance].freeze
      GPS_TAGS = %w[GPSLatitude GPSLongitude GPSAltitude GPSLatitudeRef GPSLongitudeRef GPSAltitudeRef GPSTimeStamp GPSDateStamp].freeze
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

        lat = self["GPSLatitude"]
        lon = self["GPSLongitude"]
        lat_ref = self["GPSLatitudeRef"] || "N"
        lon_ref = self["GPSLongitudeRef"] || "E"

        lat = -lat if lat_ref == "S"
        lon = -lon if lon_ref == "W"

        { latitude: lat, longitude: lon }
      end

      private

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
