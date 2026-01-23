# frozen_string_literal: true

require "spec_helper"

RSpec.describe ExifExplorer::Core::Reader do
  let(:fixture_file) { fixture_path("evidencia-com-exif.jpg") }

  describe "#initialize" do
    context "with valid file" do
      it "creates a reader instance" do
        skip "Fixture file not available" unless File.exist?(fixture_file)
        reader = described_class.new(fixture_file)
        expect(reader.file_path).to eq(File.expand_path(fixture_file))
      end
    end

    context "with non-existent file" do
      it "raises FileNotFoundError" do
        expect {
          described_class.new("/path/to/nonexistent.jpg")
        }.to raise_error(ExifExplorer::FileNotFoundError)
      end
    end

    context "with unsupported format" do
      it "raises UnsupportedFormatError" do
        # Create a temporary txt file
        require "tempfile"
        Tempfile.create(["test", ".txt"]) do |f|
          f.write("test content")
          f.flush
          expect {
            described_class.new(f.path)
          }.to raise_error(ExifExplorer::UnsupportedFormatError)
        end
      end
    end
  end

  describe "#read" do
    context "with valid image file" do
      it "returns ExifData object" do
        skip "Fixture file not available" unless File.exist?(fixture_file)
        reader = described_class.new(fixture_file)
        exif_data = reader.read

        expect(exif_data).to be_a(ExifExplorer::Core::ExifData)
        expect(exif_data.file_path).to eq(File.expand_path(fixture_file))
      end

      it "contains EXIF data" do
        skip "Fixture file not available" unless File.exist?(fixture_file)
        reader = described_class.new(fixture_file)
        exif_data = reader.read

        expect(exif_data.raw_data).not_to be_empty
      end
    end
  end

  describe "#read_tags" do
    it "reads specific tags" do
      skip "Fixture file not available" unless File.exist?(fixture_file)
      reader = described_class.new(fixture_file)
      result = reader.read_tags("Make", "Model")

      expect(result).to be_a(Hash)
      expect(result.keys).to include("Make", "Model")
    end
  end
end
