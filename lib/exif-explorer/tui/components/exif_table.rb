# frozen_string_literal: true

require "tty-table"
require "pastel"

module ExifExplorer
  module TUI
    module Components
      class ExifTable
        GROUP_COLORS = {
          camera: :cyan,
          exposure: :yellow,
          gps: :green,
          datetime: :magenta,
          image: :blue,
          other: :white
        }.freeze

        GROUP_LABELS = {
          camera: "Camera",
          exposure: "Exposure",
          gps: "GPS Location",
          datetime: "Date & Time",
          image: "Image Info",
          other: "Other Tags"
        }.freeze

        def initialize(exif_data)
          @exif_data = exif_data
          @pastel = Pastel.new
        end

        def render_grouped(width: 80)
          output = []

          @exif_data.grouped.each do |group, tags|
            next if tags.empty?

            color = GROUP_COLORS[group] || :white
            label = GROUP_LABELS[group] || group.to_s.capitalize

            output << @pastel.bold.send(color, "\n  #{label}")
            output << @pastel.send(color, "  " + "-" * (label.length + 2))

            tags.each do |tag, value|
              formatted_value = format_value(value)
              output << "  #{@pastel.dim(tag.to_s.ljust(25))} #{formatted_value}"
            end
          end

          output.join("\n")
        end

        def render_flat(width: 80)
          rows = @exif_data.to_h.map { |k, v| [k.to_s, format_value(v)] }
          return @pastel.dim("No EXIF data found.") if rows.empty?

          table = TTY::Table.new(header: %w[Tag Value], rows: rows)
          table.render(:unicode, padding: [0, 1], width: width)
        end

        def tags_for_selection
          @exif_data.all_tags.map do |tag|
            value = @exif_data[tag]
            { name: "#{tag} = #{format_value(value, max_length: 40)}", value: tag }
          end
        end

        private

        def format_value(value, max_length: 50)
          formatted = case value
                      when Array
                        value.join(", ")
                      when Time, DateTime
                        value.strftime("%Y-%m-%d %H:%M:%S")
                      when Float
                        format("%.4f", value)
                      when NilClass
                        "-"
                      else
                        value.to_s
                      end

          if formatted.length > max_length
            "#{formatted[0, max_length - 3]}..."
          else
            formatted
          end
        end
      end
    end
  end
end
