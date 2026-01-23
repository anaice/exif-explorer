# frozen_string_literal: true

module ExifExplorer
  module Core
    class BatchProcessor
      attr_reader :file_paths

      def initialize(file_paths)
        @file_paths = Array(file_paths).map { |p| File.expand_path(p) }
      end

      def read_all
        results = {}
        @file_paths.each do |path|
          results[path] = read_single(path)
        end
        results
      end

      def write_all(tags)
        results = {}
        @file_paths.each do |path|
          results[path] = write_single(path, tags)
        end
        results
      end

      def remove_tags_all(*tags)
        results = {}
        @file_paths.each do |path|
          results[path] = remove_tags_single(path, tags)
        end
        results
      end

      def copy_exif_all(source_path)
        results = {}
        @file_paths.each do |path|
          results[path] = copy_exif_single(path, source_path)
        end
        results
      end

      def self.from_directory(directory, recursive: false)
        dir = File.expand_path(directory)
        raise FileNotFoundError.new(dir) unless File.directory?(dir)

        pattern = recursive ? "**/*" : "*"
        files = Dir.glob(File.join(dir, pattern)).select do |f|
          File.file?(f) && ExifExplorer.configuration.supported_format?(f)
        end

        new(files)
      end

      private

      def read_single(path)
        Reader.new(path).read
      rescue Error => e
        { error: e.message }
      end

      def write_single(path, tags)
        Writer.new(path).write(tags)
        { success: true }
      rescue Error => e
        { success: false, error: e.message }
      end

      def remove_tags_single(path, tags)
        Writer.new(path).remove_tags(*tags)
        { success: true }
      rescue Error => e
        { success: false, error: e.message }
      end

      def copy_exif_single(path, source_path)
        Writer.new(path).copy_from(source_path)
        { success: true }
      rescue Error => e
        { success: false, error: e.message }
      end
    end
  end
end
