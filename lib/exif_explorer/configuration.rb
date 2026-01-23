# frozen_string_literal: true

module ExifExplorer
  class Configuration
    SUPPORTED_FORMATS = %w[.jpg .jpeg .tiff .tif .png .heic .heif .webp .gif .bmp].freeze

    attr_accessor :backup_original, :backup_suffix, :default_format, :color_output

    def initialize
      @backup_original = true
      @backup_suffix = "_original"
      @default_format = :table
      @color_output = true
    end

    def supported_format?(path)
      extension = File.extname(path).downcase
      SUPPORTED_FORMATS.include?(extension)
    end
  end
end
