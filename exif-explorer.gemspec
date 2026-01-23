# frozen_string_literal: true

require_relative "lib/exif-explorer/version"

Gem::Specification.new do |spec|
  spec.name = "exif-explorer"
  spec.version = ExifExplorer::VERSION
  spec.authors = ["Rafael Anaice"]
  spec.email = ["1187573+anaice@users.noreply.github.com"]

  spec.summary = "Read and write EXIF metadata from images with an interactive TUI"
  spec.description = "A Ruby gem for reading and writing EXIF metadata from images (JPEG, TIFF, PNG, HEIC) with a Terminal User Interface for interactive exploration and editing."
  spec.homepage = "https://github.com/anaice/exif-explorer"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.0.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "#{spec.homepage}/blob/main/CHANGELOG.md"

  spec.files = Dir.chdir(__dir__) do
    Dir["{lib}/**/*", "bin/*", "*.gemspec", "*.md", "LICENSE*", "Rakefile"].reject do |f|
      File.directory?(f)
    end
  end
  spec.bindir = "bin"
  spec.executables = ["exif-explorer"]
  spec.require_paths = ["lib"]

  # EXIF backend
  spec.add_dependency "mini_exiftool", "~> 2.10"

  # TUI dependencies
  spec.add_dependency "tty-prompt", "~> 0.23"
  spec.add_dependency "tty-table", "~> 0.12"
  spec.add_dependency "tty-box", "~> 0.7"
  spec.add_dependency "tty-cursor", "~> 0.7"
  spec.add_dependency "tty-screen", "~> 0.8"
  spec.add_dependency "pastel", "~> 0.8"

  # CLI
  spec.add_dependency "thor", "~> 1.3"

  # Development dependencies
  spec.add_development_dependency "bundler", "~> 2.0"
  spec.add_development_dependency "rake", "~> 13.0"
  spec.add_development_dependency "rspec", "~> 3.12"
end
