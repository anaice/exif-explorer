# frozen_string_literal: true

require "spec_helper"
require "fileutils"
require "tempfile"

RSpec.describe ExifExplorer::Core::Writer do
  let(:fixture_file) { fixture_path("evidencia-com-exif.jpg") }
  let(:temp_dir) { Dir.mktmpdir }
  let(:temp_file) { File.join(temp_dir, "test_image.jpg") }

  before do
    if File.exist?(fixture_file)
      FileUtils.cp(fixture_file, temp_file)
    end
  end

  after do
    FileUtils.rm_rf(temp_dir)
  end

  describe "#initialize" do
    context "with valid file" do
      it "creates a writer instance" do
        skip "Fixture file not available" unless File.exist?(fixture_file)
        writer = described_class.new(temp_file)
        expect(writer.file_path).to eq(File.expand_path(temp_file))
      end
    end

    context "with non-existent file" do
      it "raises FileNotFoundError" do
        expect {
          described_class.new("/path/to/nonexistent.jpg")
        }.to raise_error(ExifExplorer::FileNotFoundError)
      end
    end
  end

  describe "#write" do
    it "writes tags to the image" do
      skip "Fixture file not available" unless File.exist?(fixture_file)

      writer = described_class.new(temp_file)
      writer.write("Artist" => "Test Artist", "Copyright" => "Test Copyright")

      # Verify the tags were written
      reader = ExifExplorer::Core::Reader.new(temp_file)
      exif_data = reader.read

      expect(exif_data["Artist"]).to eq("Test Artist")
      expect(exif_data["Copyright"]).to eq("Test Copyright")
    end

    it "creates a backup file" do
      skip "Fixture file not available" unless File.exist?(fixture_file)

      writer = described_class.new(temp_file)
      writer.write("Artist" => "Test")

      backup_file = temp_file.sub(".jpg", "_original.jpg")
      expect(File.exist?(backup_file)).to be true
    end
  end

  describe "#remove_tags" do
    it "removes specified tags" do
      skip "Fixture file not available" unless File.exist?(fixture_file)

      # First write a tag
      writer = described_class.new(temp_file)
      writer.write("Artist" => "Test Artist")

      # Then remove it
      writer.remove_tags("Artist")

      # Verify it's removed
      reader = ExifExplorer::Core::Reader.new(temp_file)
      exif_data = reader.read

      expect(exif_data["Artist"]).to be_nil
    end
  end

  describe "#copy_from" do
    it "copies EXIF from another file" do
      skip "Fixture file not available" unless File.exist?(fixture_file)

      # Create another temp file
      dest_file = File.join(temp_dir, "dest_image.jpg")
      FileUtils.cp(fixture_file, dest_file)

      # Write unique tag to source
      source_writer = described_class.new(temp_file)
      source_writer.write("Artist" => "Unique Source Artist")

      # Copy from source to dest
      dest_writer = described_class.new(dest_file)
      dest_writer.copy_from(temp_file)

      # Verify the tag was copied
      reader = ExifExplorer::Core::Reader.new(dest_file)
      exif_data = reader.read

      expect(exif_data["Artist"]).to eq("Unique Source Artist")
    end
  end
end
