# EXIF Explorer

A Ruby gem for reading and writing EXIF metadata from images with an interactive Terminal User Interface (TUI).

## Features

- Read EXIF metadata from JPEG, TIFF, PNG, HEIC, and other image formats
- Write and modify EXIF tags with automatic backup
- Interactive TUI for exploring and editing metadata
- CLI commands for scripting and automation
- Batch processing for multiple files
- Export to JSON/YAML formats

## Requirements

- Ruby 3.0+
- [ExifTool](https://exiftool.org/) installed on your system

### Installing ExifTool

**Arch Linux / Manjaro:**
```bash
sudo pacman -S perl-image-exiftool
```

**Ubuntu/Debian:**
```bash
sudo apt-get install libimage-exiftool-perl
```

**macOS:**
```bash
brew install exiftool
```

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'exif-explorer'
```

And then execute:

```bash
bundle install
```

Or install it yourself as:

```bash
gem install exif-explorer
```

## Usage

### Interactive TUI

Launch the interactive interface:

```bash
exif-explorer
```

The TUI provides:
- File browser with image filtering
- Grouped EXIF data display (Camera, Exposure, GPS, Date/Time)
- Tag editing with confirmation
- Export functionality

### CLI Commands

**Read EXIF data:**
```bash
# Display as table (default)
exif-explorer read photo.jpg

# Display as JSON
exif-explorer read photo.jpg --format json

# Display grouped by category
exif-explorer read photo.jpg --grouped

# Read specific tags
exif-explorer read photo.jpg --tags Make Model DateTimeOriginal
```

**Write EXIF data:**
```bash
# Set tags
exif-explorer write photo.jpg --set "Artist=John Doe" --set "Copyright=2024"

# Without backup
exif-explorer write photo.jpg --set "Artist=John" --no-backup
```

**Remove EXIF data:**
```bash
# Remove specific tags
exif-explorer remove photo.jpg --tags Artist Copyright

# Remove all EXIF
exif-explorer remove photo.jpg --all
```

**Copy EXIF between files:**
```bash
exif-explorer copy source.jpg destination.jpg
```

### Ruby API

```ruby
require 'exif-explorer'

# Read EXIF data
exif = ExifExplorer.read('photo.jpg')

# Access tags
puts exif['Make']
puts exif['Model']
puts exif['DateTimeOriginal']

# Access grouped data
puts exif.camera    # Camera-related tags
puts exif.exposure  # Exposure settings
puts exif.gps       # GPS coordinates
puts exif.datetime  # Date/time tags

# GPS coordinates (automatically converted from DMS to decimal)
if exif.has_gps?
  coords = exif.gps_coordinates
  puts "Location: #{coords[:latitude]}, #{coords[:longitude]}"
  # => Location: -25.408611, -49.323325

  # Direct Google Maps URL
  puts exif.google_maps_url
  # => https://www.google.com/maps?q=-25.408611,-49.323325
end

# Write EXIF data
ExifExplorer.write('photo.jpg', {
  'Artist' => 'John Doe',
  'Copyright' => '2024 All Rights Reserved'
})

# Batch processing
results = ExifExplorer.batch_read(['photo1.jpg', 'photo2.jpg', 'photo3.jpg'])

# Configure settings
ExifExplorer.configure do |config|
  config.backup_original = true
  config.backup_suffix = '_backup'
  config.color_output = true
end
```

## Configuration

```ruby
ExifExplorer.configure do |config|
  # Create backup before modifying (default: true)
  config.backup_original = true

  # Backup file suffix (default: "_original")
  config.backup_suffix = "_original"

  # Default output format (default: :table)
  config.default_format = :table

  # Enable colored output (default: true)
  config.color_output = true
end
```

## Supported File Formats

- JPEG (.jpg, .jpeg)
- TIFF (.tiff, .tif)
- PNG (.png)
- HEIC/HEIF (.heic, .heif)
- WebP (.webp)
- GIF (.gif)
- BMP (.bmp)

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests.

```bash
bundle install
bundle exec rspec
```

## License

The gem is available as open source under the terms of the [MIT License](LICENSE.txt).
