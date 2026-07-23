# frozen_string_literal: true

require_relative "lib/rails/domternal/version"

Gem::Specification.new do |spec|
  spec.name = "rails-domternal"
  spec.version = Rails::Domternal::VERSION
  spec.authors = ["Stefan"]
  spec.email = ["stefan@getrestful.ch"]

  spec.summary = "Domternal rich text editor with notion style UI and integration for Rails, as a drop-in ActionText replacement."
  spec.description = "Wraps the Domternal (ProseMirror-based) editor with a has_rich_domternal model " \
    "attribute, a domternal_area form helper, and Active Storage-backed image uploads " \
    "so it can be adopted with the same shape as ActionText."
  spec.homepage = "https://github.com/getrestful/rails-domternal"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.2.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage

  gemspec = File.basename(__FILE__)
  spec.files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true).reject do |f|
      (f == gemspec) ||
        f.start_with?(*%w[bin/ Gemfile .gitignore test/ demo/])
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "rails", ">= 7.1"
end
