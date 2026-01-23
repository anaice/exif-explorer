# frozen_string_literal: true

require "json"

module ExifExplorer
  module Formatters
    class JsonFormatter
      def initialize(exif_data, pretty: true)
        @exif_data = exif_data
        @pretty = pretty
      end

      def format
        if @pretty
          JSON.pretty_generate(@exif_data.to_h)
        else
          @exif_data.to_h.to_json
        end
      end

      def format_grouped
        if @pretty
          JSON.pretty_generate(@exif_data.grouped)
        else
          @exif_data.grouped.to_json
        end
      end
    end
  end
end
