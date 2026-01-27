# frozen_string_literal: true

require "net/http"
require "uri"
require "openssl"
require "chunky_png"
require "mini_magick"

module ExifExplorer
  module Core
    class MapOverlay
      TILE_SIZE = 256
      USER_AGENT = "exif-explorer/#{ExifExplorer::VERSION}"
      DEFAULT_PROVIDER = "https://tile.openstreetmap.org/{z}/{x}/{y}.png"

      # Path to pin SVG asset
      PIN_SVG_PATH = File.expand_path("../../../extras/svg/map-pin.svg", __dir__)

      def initialize(lat, lng, size: 150, zoom: 16, provider: DEFAULT_PROVIDER)
        @lat = lat
        @lng = lng
        @size = size
        @zoom = zoom
        @provider = provider
      end

      def generate
        # Calculate which tiles we need
        center_fraction = GeoUtils.lat_lng_to_tile_fraction(@lat, @lng, @zoom)
        center_tile = GeoUtils.lat_lng_to_tile(@lat, @lng, @zoom)

        # Calculate pixel position within the center tile
        pixel_in_tile_x = ((center_fraction[:x] - center_tile[:x]) * TILE_SIZE).round
        pixel_in_tile_y = ((center_fraction[:y] - center_tile[:y]) * TILE_SIZE).round

        # Determine how many tiles we need in each direction
        half_size = @size / 2

        # Fetch required tiles
        tiles_data = fetch_tiles_around(center_tile, pixel_in_tile_x, pixel_in_tile_y, half_size)

        # Compose into single canvas
        canvas = compose_canvas(tiles_data, center_tile, pixel_in_tile_x, pixel_in_tile_y, half_size)

        # Draw pin marker
        draw_pin_marker(canvas)

        # Note: Border is now handled by ImageStamper to support rounded corners

        canvas
      end

      private

      def fetch_tiles_around(center_tile, px_x, px_y, half_size)
        tiles = {}

        # Calculate tile range needed
        min_dx = ((px_x - half_size) / TILE_SIZE.to_f).floor
        max_dx = ((px_x + half_size) / TILE_SIZE.to_f).ceil
        min_dy = ((px_y - half_size) / TILE_SIZE.to_f).floor
        max_dy = ((px_y + half_size) / TILE_SIZE.to_f).ceil

        (min_dy..max_dy).each do |dy|
          (min_dx..max_dx).each do |dx|
            tile_x = center_tile[:x] + dx
            tile_y = center_tile[:y] + dy
            key = "#{dx},#{dy}"
            tiles[key] = {
              dx: dx,
              dy: dy,
              data: fetch_tile(tile_x, tile_y)
            }
          end
        end

        tiles
      end

      def compose_canvas(tiles_data, center_tile, px_x, px_y, half_size)
        # Create canvas of exact size needed
        canvas = ChunkyPNG::Image.new(@size, @size, ChunkyPNG::Color::WHITE)

        # Calculate the offset from the top-left of our canvas to the center point
        canvas_center_x = @size / 2
        canvas_center_y = @size / 2

        tiles_data.each do |_key, tile_info|
          dx = tile_info[:dx]
          dy = tile_info[:dy]
          tile_img = tile_info[:data]

          # Calculate where this tile starts relative to the GPS point
          tile_start_x = dx * TILE_SIZE
          tile_start_y = dy * TILE_SIZE

          # Calculate where to place this tile on our canvas
          # The GPS point is at (px_x, px_y) within the center tile (dx=0, dy=0)
          # We want the GPS point to be at canvas center
          dest_x = canvas_center_x - px_x + tile_start_x
          dest_y = canvas_center_y - px_y + tile_start_y

          # Compose the tile onto the canvas
          compose_tile_onto_canvas(canvas, tile_img, dest_x, dest_y)
        end

        canvas
      end

      def compose_tile_onto_canvas(canvas, tile_img, dest_x, dest_y)
        # Calculate the visible portion of the tile
        src_x = [0, -dest_x].max
        src_y = [0, -dest_y].max
        dst_x = [0, dest_x].max
        dst_y = [0, dest_y].max

        # Calculate how much of the tile is visible
        width = [tile_img.width - src_x, canvas.width - dst_x].min
        height = [tile_img.height - src_y, canvas.height - dst_y].min

        return if width <= 0 || height <= 0

        # Copy pixels
        (0...height).each do |y|
          (0...width).each do |x|
            pixel = tile_img[src_x + x, src_y + y]
            canvas[dst_x + x, dst_y + y] = pixel
          end
        end
      end

      def fetch_tile(x, y)
        url = @provider
          .gsub("{z}", @zoom.to_s)
          .gsub("{x}", x.to_s)
          .gsub("{y}", y.to_s)

        uri = URI(url)

        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = uri.scheme == "https"
        http.verify_mode = OpenSSL::SSL::VERIFY_PEER
        http.open_timeout = 10
        http.read_timeout = 10

        # Use system CA certificates
        if File.exist?("/etc/ssl/certs/ca-certificates.crt")
          http.ca_file = "/etc/ssl/certs/ca-certificates.crt"
        elsif File.exist?("/etc/pki/tls/certs/ca-bundle.crt")
          http.ca_file = "/etc/pki/tls/certs/ca-bundle.crt"
        elsif File.exist?("/etc/ssl/cert.pem")
          http.ca_file = "/etc/ssl/cert.pem"
        end

        request = Net::HTTP::Get.new(uri)
        request["User-Agent"] = USER_AGENT

        response = http.request(request)

        raise TileFetchError, url unless response.is_a?(Net::HTTPSuccess)

        ChunkyPNG::Image.from_blob(response.body)
      rescue OpenSSL::SSL::SSLError
        # Retry without strict SSL verification as fallback
        http.verify_mode = OpenSSL::SSL::VERIFY_NONE
        response = http.request(request)
        raise TileFetchError, url unless response.is_a?(Net::HTTPSuccess)
        ChunkyPNG::Image.from_blob(response.body)
      rescue StandardError => e
        raise TileFetchError, "#{url} - #{e.message}"
      end

      def draw_pin_marker(canvas)
        center_x = canvas.width / 2
        center_y = canvas.height / 2

        # Try to use SVG pin if available
        if File.exist?(PIN_SVG_PATH)
          draw_svg_pin(canvas, center_x, center_y)
        else
          draw_simple_pin(canvas, center_x, center_y)
        end
      end

      def draw_svg_pin(canvas, center_x, center_y)
        pin_size = 32  # Size of the pin in pixels

        # Convert SVG to PNG using MiniMagick
        pin_png = Tempfile.new(["pin", ".png"])
        begin
          MiniMagick::Tool::Convert.new do |convert|
            convert.background("none")
            convert.density(300)
            convert << PIN_SVG_PATH
            convert.resize("#{pin_size}x#{pin_size}")
            convert << pin_png.path
          end

          pin_img = ChunkyPNG::Image.from_file(pin_png.path)

          # Position pin so the point is at the center
          # The pin point is at the bottom center of the image
          dest_x = center_x - (pin_img.width / 2)
          dest_y = center_y - pin_img.height

          # Compose with alpha blending
          (0...pin_img.height).each do |y|
            (0...pin_img.width).each do |x|
              px = dest_x + x
              py = dest_y + y
              next if px < 0 || px >= canvas.width || py < 0 || py >= canvas.height

              pin_pixel = pin_img[x, y]
              alpha = ChunkyPNG::Color.a(pin_pixel)
              next if alpha == 0

              if alpha == 255
                canvas[px, py] = pin_pixel
              else
                # Alpha blend
                canvas[px, py] = ChunkyPNG::Color.compose(pin_pixel, canvas[px, py])
              end
            end
          end
        ensure
          pin_png.close
          pin_png.unlink
        end
      end

      def draw_simple_pin(canvas, center_x, center_y)
        # Fallback: draw a simple teardrop pin
        pin_color = ChunkyPNG::Color.rgba(220, 53, 69, 255)
        border_color = ChunkyPNG::Color.rgba(90, 0, 0, 255)

        # Draw teardrop shape
        # Head (circle at top)
        head_y = center_y - 20
        head_radius = 8

        # Draw head circle with border
        draw_filled_circle(canvas, center_x, head_y, head_radius + 1, border_color)
        draw_filled_circle(canvas, center_x, head_y, head_radius - 1, pin_color)

        # Draw point (triangle)
        (0..15).each do |i|
          width = ((15 - i) * head_radius / 15.0).round
          y = head_y + head_radius - 2 + i
          next if y >= canvas.height

          (-width..width).each do |dx|
            x = center_x + dx
            next if x < 0 || x >= canvas.width
            canvas[x, y] = pin_color
          end
        end

        # Inner circle (dark)
        draw_filled_circle(canvas, center_x, head_y, 4, ChunkyPNG::Color.rgba(14, 35, 46, 255))
      end

      def draw_filled_circle(canvas, cx, cy, radius, color)
        (-radius..radius).each do |dy|
          (-radius..radius).each do |dx|
            if dx * dx + dy * dy <= radius * radius
              px = cx + dx
              py = cy + dy
              if px >= 0 && px < canvas.width && py >= 0 && py < canvas.height
                canvas[px, py] = color
              end
            end
          end
        end
      end

      def draw_border(canvas)
        border_color = ChunkyPNG::Color.rgba(80, 80, 80, 255)

        # Draw 2px border
        2.times do |i|
          (0...canvas.width).each do |x|
            canvas[x, i] = border_color
            canvas[x, canvas.height - 1 - i] = border_color
          end
          (0...canvas.height).each do |y|
            canvas[i, y] = border_color
            canvas[canvas.width - 1 - i, y] = border_color
          end
        end
      end
    end
  end
end
