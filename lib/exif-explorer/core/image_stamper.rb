# frozen_string_literal: true

require "mini_magick"
require "chunky_png"
require "tempfile"
require "fileutils"

module ExifExplorer
  module Core
    class ImageStamper
      DEFAULT_OPTIONS = {
        show_compass: true,
        show_minimap: true,
        show_info: true,
        geocode: true,
        geocoder: :nominatim,
        # Minimap options
        minimap_width: 150,
        minimap_height: 150,
        minimap_zoom: 16,
        minimap_opacity: 0.6,
        minimap_border_radius: 8,
        # Compass options
        compass_width: 90,
        compass_height: 90,
        compass_style: 1,
        compass_arrow_color: "#00d4d4",
        # Info box options
        info_font_size: 10,
        info_font_family: "DejaVu-Sans-Mono",
        info_font_color: "#ffffff",
        info_bg_color: "#000000",
        info_bg_opacity: 0.50,
        info_border_radius: 8,
        # General
        margin: 10
      }.freeze

      attr_reader :image_path, :exif_data, :options

      def initialize(image_path, options = {})
        @image_path = File.expand_path(image_path)
        @options = DEFAULT_OPTIONS.merge(options)
        @exif_data = ExifExplorer.read(@image_path)

        validate!
      end

      def stamp(output_path = nil)
        output_path ||= generate_output_path
        output_path = File.expand_path(output_path)

        # Gather all the data we need
        coords = @exif_data.gps_coordinates
        direction = @exif_data.image_direction if @exif_data.has_image_direction?
        address = fetch_address(coords) if @options[:geocode]
        datetime = @exif_data["DateTimeOriginal"]

        # Generate overlays
        minimap_file = generate_minimap(coords) if @options[:show_minimap]
        compass_file = generate_compass(direction) if @options[:show_compass]

        # Compose final image
        compose_image(output_path, minimap_file, compass_file, direction, address, datetime)

        # Cleanup temp files
        minimap_file&.close
        minimap_file&.unlink
        compass_file&.close
        compass_file&.unlink

        output_path
      end

      private

      def validate!
        raise FileNotFoundError, @image_path unless File.exist?(@image_path)
        raise NoGPSDataError, @image_path unless @exif_data.has_gps?
      end

      def generate_output_path
        dir = File.dirname(@image_path)
        base = File.basename(@image_path, ".*")
        ext = File.extname(@image_path)
        File.join(dir, "#{base}_stamped#{ext}")
      end

      def fetch_address(coords)
        return nil unless @options[:geocode]

        Geocoder.reverse(coords[:latitude], coords[:longitude], provider: @options[:geocoder])
      rescue GeocodingError
        nil
      end

      def generate_minimap(coords)
        width = @options[:minimap_width] || 150
        height = @options[:minimap_height] || 150
        size = [width, height].max  # Use larger dimension for tile fetching

        overlay = MapOverlay.new(
          coords[:latitude],
          coords[:longitude],
          size: size,
          zoom: @options[:minimap_zoom]
        )

        png = overlay.generate
        tempfile = Tempfile.new(["minimap", ".png"])

        # Resize to exact dimensions if width != height
        if width != height
          # Save temp, resize with MiniMagick
          png.save(tempfile.path)
          img = MiniMagick::Image.open(tempfile.path)
          img.resize("#{width}x#{height}!")
          img.write(tempfile.path)
        else
          png.save(tempfile.path)
        end

        # Apply border radius if specified
        border_radius = @options[:minimap_border_radius] || 0
        if border_radius > 0
          apply_border_radius(tempfile.path, width, height, border_radius)
        end

        tempfile
      end

      def apply_border_radius(image_path, width, height, radius)
        temp_output = Tempfile.new(["rounded", ".png"])

        begin
          # Use ImageMagick to create rounded corners with transparency
          # This approach creates a mask and applies it in a single pipeline
          MiniMagick::Tool::Convert.new do |convert|
            # Start with the source image
            convert << image_path
            convert.alpha("set")

            # Create mask inline using parentheses
            convert.stack do |stack|
              stack.size("#{width}x#{height}")
              stack.xc("none")
              stack.fill("white")
              stack.draw("roundrectangle 0,0,#{width - 1},#{height - 1},#{radius},#{radius}")
            end

            # Use the mask to set alpha channel
            convert.compose("CopyOpacity")
            convert.composite

            convert << temp_output.path
          end

          # Add rounded border
          MiniMagick::Tool::Convert.new do |convert|
            convert << temp_output.path
            convert.fill("none")
            convert.stroke("rgba(80,80,80,0)")
            convert.strokewidth(2)
            convert.draw("roundrectangle 1,1,#{width - 2},#{height - 2},#{radius - 1},#{radius - 1}")
            convert << image_path
          end
        ensure
          temp_output.close
          temp_output.unlink
        end
      end

      COMPASS_SVG_PATHS = {
        1 => File.expand_path("../../../extras/svg/compass-style1.svg", __dir__),
        2 => File.expand_path("../../../extras/svg/compass-style2.svg", __dir__),
        3 => File.expand_path("../../../extras/svg/compass-style3.svg", __dir__)
      }.freeze

      def generate_compass(direction)
        width = @options[:compass_width] || 90
        height = @options[:compass_height] || 90
        size = [width, height].max
        tempfile = Tempfile.new(["compass", ".png"])

        generate_svg_compass(tempfile, size, direction)

        # Resize to exact dimensions if needed
        if width != height
          img = MiniMagick::Image.open(tempfile.path)
          img.resize("#{width}x#{height}!")
          img.write(tempfile.path)
        end

        tempfile
      end

      def generate_svg_compass(tempfile, size, direction)
        style = @options[:compass_style] || 3
        svg_path = COMPASS_SVG_PATHS[style] || COMPASS_SVG_PATHS[3]

        unless File.exist?(svg_path)
          generate_fallback_compass(tempfile, size, direction)
          return
        end

        # Convert compass SVG to PNG at high quality
        compass_png = Tempfile.new(["compass_base", ".png"])

        MiniMagick::Tool::Convert.new do |convert|
          convert.background("none")
          convert.density(300)
          convert << svg_path
          convert.resize("#{size}x#{size}")
          convert << compass_png.path
        end

        compass_img = MiniMagick::Image.open(compass_png.path)

        if direction
          # ROTATE THE COMPASS (not the arrow)
          # The arrow always points UP (camera direction)
          # The compass rotates so the correct cardinal direction is at top
          degrees = direction[:degrees]

          compass_img.combine_options do |c|
            c.background("none")
            c.rotate(degrees.to_s)
          end

          # Re-center after rotation (rotation may change dimensions)
          compass_img.combine_options do |c|
            c.gravity("center")
            c.background("none")
            c.extent("#{size}x#{size}")
          end
        end

        # Draw the fixed marker triangle pointing UP (camera direction indicator)
        center = size / 2
        arrow_color = @options[:compass_arrow_color] || "#00d4d4"

        # Elongated triangle from center to near top edge
        triangle_top = (size * 0.12).round      # Distance from top edge
        triangle_bottom = center + 2            # Slightly below center
        triangle_width = (size * 0.06).round    # Half-width at base

        compass_img.combine_options do |c|
          c.fill(arrow_color)
          c.stroke("none")
          # Draw elongated isoceles triangle pointing UP
          c.draw("polygon #{center},#{triangle_top} #{center - triangle_width},#{triangle_bottom} #{center + triangle_width},#{triangle_bottom}")
        end

        compass_img.write(tempfile.path)
        compass_png.close
        compass_png.unlink
      end

      def generate_fallback_compass(tempfile, size, direction)
        # Fallback: generate compass programmatically
        MiniMagick::Tool::Convert.new do |convert|
          convert.size("#{size}x#{size}")
          convert.xc("none")

          # Draw dark circle background
          convert.fill("rgba(30,30,30,220)")
          convert.stroke("rgba(60,60,60,255)")
          convert.strokewidth(2)
          convert.draw("circle #{size / 2},#{size / 2} #{size / 2},3")

          # Draw N, S, E, W
          convert.fill("white")
          convert.stroke("none")
          convert.font("DejaVu-Sans-Bold")
          convert.pointsize(12)
          convert.gravity("North")
          convert.draw("text 0,8 'N'")
          convert.gravity("South")
          convert.draw("text 0,8 'S'")
          convert.gravity("East")
          convert.draw("text 8,0 'E'")
          convert.gravity("West")
          convert.draw("text 8,0 'W'")

          # Draw direction arrow if available
          if direction
            degrees = direction[:degrees]
            rad = (degrees - 90) * Math::PI / 180
            arrow_length = size / 3
            center = size / 2

            end_x = (center + arrow_length * Math.cos(rad)).round
            end_y = (center + arrow_length * Math.sin(rad)).round

            convert.stroke("rgba(0,212,212,255)")
            convert.strokewidth(3)
            convert.draw("line #{center},#{center} #{end_x},#{end_y}")
          end

          convert << tempfile.path
        end
      end

      def compose_image(output_path, minimap_file, compass_file, direction, address, datetime)
        image = MiniMagick::Image.open(@image_path)

        # Auto-orient the image based on EXIF orientation
        image.auto_orient

        margin = @options[:margin]

        # Calculate info bar height for positioning minimap above it
        info_bar_height = 0
        if @options[:show_info]
          info_bar_height = calculate_info_bar_height(image, direction, address, datetime)
        end

        # Add minimap (bottom-left, above info bar) with opacity
        if minimap_file
          minimap_img = MiniMagick::Image.open(minimap_file.path)

          # Apply opacity to minimap
          opacity = @options[:minimap_opacity] || 0.6
          if opacity < 1.0
            minimap_img.combine_options do |c|
              c.alpha("on")
              c.channel("A")
              c.evaluate("multiply", opacity.to_s)
              c.channel("all")
            end
          end

          # Position above info bar
          minimap_bottom_offset = margin + info_bar_height + (info_bar_height > 0 ? margin : 0)

          image = image.composite(minimap_img) do |c|
            c.compose "Over"
            c.gravity "SouthWest"
            c.geometry "+#{margin}+#{minimap_bottom_offset}"
          end
        end

        # Add compass (top-left)
        if compass_file
          image = image.composite(MiniMagick::Image.open(compass_file.path)) do |c|
            c.compose "Over"
            c.gravity "NorthWest"
            c.geometry "+#{margin}+#{margin}"
          end
        end

        # Add info bar (bottom, full width)
        if @options[:show_info]
          image = add_info_overlay(image, direction, address, datetime)
        end

        image.write(output_path)
      end

      def calculate_info_bar_height(image, direction, address, datetime)
        font_size = @options[:info_font_size] || 16
        padding_v = 8
        line_height = font_size + 4

        is_landscape = image.width > image.height
        lines = build_info_lines_for_orientation(direction, address, datetime, is_landscape)

        return 0 if lines.empty?

        lines.size * line_height + padding_v * 2
      end

      def add_info_overlay(image, direction, address, datetime)
        # Get options
        font_size = @options[:info_font_size] || 16
        font_family = @options[:info_font_family] || "DejaVu-Sans-Mono"
        font_color = @options[:info_font_color] || "#ffffff"
        bg_color = @options[:info_bg_color] || "#000000"
        bg_opacity = @options[:info_bg_opacity] || 0.5
        border_radius = @options[:info_border_radius] || 8
        margin = @options[:margin] || 10

        # Detect orientation
        is_landscape = image.width > image.height

        # Build info text based on orientation
        lines = build_info_lines_for_orientation(direction, address, datetime, is_landscape)
        return image if lines.empty?

        line_height = font_size + 4
        padding_v = 8
        padding_h = 14

        # Calculate bar dimensions (full width)
        bar_height = lines.size * line_height + padding_v * 2
        rect_x1 = margin
        rect_y1 = image.height - bar_height - margin
        rect_x2 = image.width - margin
        rect_y2 = image.height - margin

        # Convert hex color to rgba
        bg_rgba = hex_to_rgba(bg_color, bg_opacity)

        # Draw background bar with rounded corners
        image.combine_options do |c|
          c.fill(bg_rgba)
          if border_radius > 0
            c.draw("roundrectangle #{rect_x1},#{rect_y1} #{rect_x2},#{rect_y2} #{border_radius},#{border_radius}")
          else
            c.draw("rectangle #{rect_x1},#{rect_y1} #{rect_x2},#{rect_y2}")
          end
        end

        # Add text lines using annotate for better positioning
        lines.each_with_index do |line, index|
          text_y = rect_y1 + padding_v + (index * line_height) + line_height - 3

          image.combine_options do |c|
            c.fill(font_color)
            c.font(font_family)
            c.pointsize(font_size)
            c.draw("text #{rect_x1 + padding_h},#{text_y} '#{escape_text(line)}'")
          end
        end

        image
      end

      def build_info_lines_for_orientation(direction, address, datetime, is_landscape)
        # Format individual parts
        date_str = datetime ? GeoUtils.format_datetime(datetime) : nil
        dir_str = direction ? GeoUtils.format_direction(direction[:degrees]) : nil

        # 3 lines:
        # Line 1: date and direction
        # Line 2: street address
        # Line 3: neighborhood / city, state
        lines = []

        # Line 1
        line1_parts = [date_str, dir_str].compact.reject(&:empty?)
        lines << line1_parts.join("   ") unless line1_parts.empty?

        # Lines 2 and 3 from address
        if address
          # Line 2: street
          if address[:street]
            street = address[:street]
            street = "#{address[:number]} #{street}" if address[:number]
            lines << street
          end

          # Line 3: neighborhood / city, state
          line3_parts = []
          line3_parts << address[:neighborhood] if address[:neighborhood]
          if address[:city]
            city = address[:city]
            city = "#{city}, #{address[:state]}" if address[:state]
            line3_parts << city
          end
          lines << line3_parts.join(" / ") unless line3_parts.empty?
        end

        lines
      end

      def hex_to_rgba(hex, opacity)
        # Convert hex color (#RRGGBB or #RGB) to rgba string
        hex = hex.gsub("#", "")
        if hex.length == 3
          hex = hex.chars.map { |c| c * 2 }.join
        end
        r = hex[0..1].to_i(16)
        g = hex[2..3].to_i(16)
        b = hex[4..5].to_i(16)
        "rgba(#{r},#{g},#{b},#{opacity})"
      end

      def build_info_lines(direction, address, datetime)
        lines = []

        # Date/time
        if datetime
          formatted_date = GeoUtils.format_datetime(datetime)
          lines << formatted_date if formatted_date
        end

        # Direction
        if direction
          lines << GeoUtils.format_direction(direction[:degrees])
        end

        # Address
        if address
          if address[:street]
            street_line = address[:street]
            street_line = "#{address[:number]} #{street_line}" if address[:number]
            lines << street_line
          end
          lines << address[:neighborhood] if address[:neighborhood]
          if address[:city]
            city_line = address[:city]
            city_line = "#{city_line}, #{address[:state]}" if address[:state]
            lines << city_line
          end
        end

        lines.compact.reject(&:empty?)
      end

      def escape_text(text)
        text.to_s.gsub("'", "\\\\'").gsub('"', '\\"')
      end
    end
  end
end
