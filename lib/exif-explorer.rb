# frozen_string_literal: true

require_relative "exif-explorer/version"
require_relative "exif-explorer/errors"
require_relative "exif-explorer/configuration"
require_relative "exif-explorer/core/exif_data"
require_relative "exif-explorer/core/reader"
require_relative "exif-explorer/core/writer"
require_relative "exif-explorer/core/batch_processor"
require_relative "exif-explorer/formatters/json_formatter"
require_relative "exif-explorer/formatters/yaml_formatter"
require_relative "exif-explorer/formatters/table_formatter"

module ExifExplorer
  class << self
    attr_writer :configuration

    def configuration
      @configuration ||= Configuration.new
    end

    def configure
      yield(configuration)
    end

    def read(file_path)
      Core::Reader.new(file_path).read
    end

    def write(file_path, tags)
      Core::Writer.new(file_path).write(tags)
    end

    def batch_read(file_paths)
      Core::BatchProcessor.new(file_paths).read_all
    end

    def batch_write(file_paths, tags)
      Core::BatchProcessor.new(file_paths).write_all(tags)
    end
  end
end
