# frozen_string_literal: true

require "yaml"

module ExifExplorer
  module Formatters
    class YamlFormatter
      def initialize(exif_data)
        @exif_data = exif_data
      end

      def format
        @exif_data.to_h.to_yaml
      end

      def format_grouped
        @exif_data.grouped.to_yaml
      end
    end
  end
end
