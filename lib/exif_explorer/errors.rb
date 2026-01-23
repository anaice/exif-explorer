# frozen_string_literal: true

module ExifExplorer
  class Error < StandardError; end

  class FileNotFoundError < Error
    def initialize(path)
      super("File not found: #{path}")
    end
  end

  class UnsupportedFormatError < Error
    def initialize(path)
      extension = File.extname(path)
      super("Unsupported file format: #{extension}")
    end
  end

  class ExifToolNotFoundError < Error
    def initialize
      super("ExifTool is not installed or not in PATH. Please install it: https://exiftool.org/")
    end
  end

  class ReadError < Error
    def initialize(path, message)
      super("Failed to read EXIF from #{path}: #{message}")
    end
  end

  class WriteError < Error
    def initialize(path, message)
      super("Failed to write EXIF to #{path}: #{message}")
    end
  end

  class ValidationError < Error; end
end
