# frozen_string_literal: true

require "mini_exiftool"

module ExifExplorer
  module Core
    class Reader
      attr_reader :file_path

      def initialize(file_path)
        @file_path = File.expand_path(file_path)
        validate!
      end

      def read
        exif = MiniExiftool.new(@file_path)
        ExifData.new(@file_path, exif.to_hash)
      rescue MiniExiftool::Error => e
        raise ReadError.new(@file_path, e.message)
      rescue Errno::ENOENT
        raise ExifToolNotFoundError.new
      end

      def read_tags(*tags)
        exif = MiniExiftool.new(@file_path)
        result = {}
        tags.flatten.each do |tag|
          result[tag] = exif[tag]
        end
        result
      rescue MiniExiftool::Error => e
        raise ReadError.new(@file_path, e.message)
      end

      private

      def validate!
        raise FileNotFoundError.new(@file_path) unless File.exist?(@file_path)
        raise UnsupportedFormatError.new(@file_path) unless ExifExplorer.configuration.supported_format?(@file_path)
      end
    end
  end
end
