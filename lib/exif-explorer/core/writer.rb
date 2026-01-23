# frozen_string_literal: true

require "mini_exiftool"
require "fileutils"

module ExifExplorer
  module Core
    class Writer
      attr_reader :file_path

      def initialize(file_path)
        @file_path = File.expand_path(file_path)
        validate!
      end

      def write(tags)
        backup_file if ExifExplorer.configuration.backup_original

        exif = MiniExiftool.new(@file_path)
        tags.each do |tag, value|
          exif[tag.to_s] = value
        end
        exif.save
      rescue MiniExiftool::Error => e
        restore_backup if ExifExplorer.configuration.backup_original
        raise WriteError.new(@file_path, e.message)
      end

      def remove_tags(*tags)
        backup_file if ExifExplorer.configuration.backup_original

        exif = MiniExiftool.new(@file_path)
        tags.flatten.each do |tag|
          exif[tag.to_s] = nil
        end
        exif.save
      rescue MiniExiftool::Error => e
        restore_backup if ExifExplorer.configuration.backup_original
        raise WriteError.new(@file_path, e.message)
      end

      def remove_all_exif
        backup_file if ExifExplorer.configuration.backup_original

        # Use exiftool directly to remove all metadata
        result = system("exiftool", "-all=", "-overwrite_original", @file_path)
        raise WriteError.new(@file_path, "Failed to remove all EXIF data") unless result
      end

      def copy_from(source_path)
        source = File.expand_path(source_path)
        raise FileNotFoundError.new(source) unless File.exist?(source)

        backup_file if ExifExplorer.configuration.backup_original

        result = system("exiftool", "-TagsFromFile", source, "-all:all", "-overwrite_original", @file_path)
        raise WriteError.new(@file_path, "Failed to copy EXIF from #{source}") unless result
      end

      private

      def validate!
        raise FileNotFoundError.new(@file_path) unless File.exist?(@file_path)
        raise UnsupportedFormatError.new(@file_path) unless ExifExplorer.configuration.supported_format?(@file_path)
      end

      def backup_path
        ext = File.extname(@file_path)
        base = File.basename(@file_path, ext)
        dir = File.dirname(@file_path)
        suffix = ExifExplorer.configuration.backup_suffix
        File.join(dir, "#{base}#{suffix}#{ext}")
      end

      def backup_file
        return if File.exist?(backup_path)

        FileUtils.cp(@file_path, backup_path)
      end

      def restore_backup
        return unless File.exist?(backup_path)

        FileUtils.mv(backup_path, @file_path)
      end
    end
  end
end
