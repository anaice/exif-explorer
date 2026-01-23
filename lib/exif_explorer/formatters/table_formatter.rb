# frozen_string_literal: true

require "tty-table"
require "pastel"

module ExifExplorer
  module Formatters
    class TableFormatter
      GROUP_LABELS = {
        camera: "Camera",
        exposure: "Exposure",
        gps: "GPS",
        datetime: "Date/Time",
        image: "Image",
        other: "Other"
      }.freeze

      def initialize(exif_data, color: true)
        @exif_data = exif_data
        @pastel = Pastel.new(enabled: color)
      end

      def format
        rows = @exif_data.to_h.map { |k, v| [k.to_s, format_value(v)] }
        return "No EXIF data found." if rows.empty?

        table = TTY::Table.new(header: %w[Tag Value], rows: rows)
        table.render(:unicode, padding: [0, 1], width: terminal_width)
      end

      def format_grouped
        output = []

        @exif_data.grouped.each do |group, tags|
          next if tags.empty?

          label = GROUP_LABELS[group] || group.to_s.capitalize
          output << @pastel.bold.cyan("== #{label} ==")

          rows = tags.map { |k, v| [k.to_s, format_value(v)] }
          table = TTY::Table.new(rows: rows)
          output << table.render(:unicode, padding: [0, 1], width: terminal_width)
          output << ""
        end

        output.join("\n")
      end

      private

      def format_value(value)
        case value
        when Array
          value.join(", ")
        when Time, DateTime
          value.strftime("%Y-%m-%d %H:%M:%S")
        when Float
          format("%.4f", value)
        when NilClass
          "-"
        else
          value.to_s.slice(0, 60)
        end
      end

      def terminal_width
        require "tty-screen"
        TTY::Screen.width
      rescue
        80
      end
    end
  end
end
