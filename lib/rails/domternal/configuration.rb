# frozen_string_literal: true

module Rails
  module Domternal
    class Configuration
      # Symbolic extension keys resolved client-side by app/assets/javascripts/domternal/extensions.js
      attr_accessor :default_extensions

      # :full, :minimal, :notion, or false. :notion swaps the fixed toolbar for a
      # selection bubble menu + a "+" floating menu, matching the block handle/slash
      # command UI the :block_controls extension adds — pair the two.
      attr_accessor :toolbar

      # :light, :dark, or :auto
      attr_accessor :theme

      # :importmap, :jsbundling, or :cdn — how the install generator wires up JS. Informational
      # at runtime; only the generator branches on it.
      attr_accessor :asset_strategy

      # npm dist-tag/version used when pinning packages from a CDN (importmap/:cdn strategies).
      attr_accessor :npm_version

      attr_accessor :allowed_mime_types
      attr_accessor :max_file_size

      # HTML tags/attributes allowed through the safelist sanitizer applied to incoming bodies.
      attr_accessor :sanitizer_allowed_tags
      attr_accessor :sanitizer_allowed_attributes

      def initialize
        @default_extensions = %i[starter_kit image]
        @toolbar = :full
        @theme = :light
        @asset_strategy = :importmap
        @npm_version = "latest"
        @allowed_mime_types = %w[image/png image/jpeg image/gif image/webp image/svg+xml image/avif]
        @max_file_size = 10.megabytes

        @sanitizer_allowed_tags = %w[
          p br div span
          h1 h2 h3 h4 h5 h6
          strong em b i u s del ins mark sub sup code pre
          ul ol li blockquote
          a img figure figcaption
          table thead tbody tr th td
          hr details summary
        ]
        @sanitizer_allowed_attributes = %w[
          href src alt title width height loading crossorigin
          colspan rowspan align style class data-type data-id data-label
        ]
      end
    end
  end
end
