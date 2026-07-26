# frozen_string_literal: true

module Domternal
  # Holds the HTML body + Active Storage embeds for a single has_rich_domternal attribute.
  # Body is stored as the same sanitized HTML the Domternal editor renders/re-parses
  # (Domternal's `Editor`/`DomternalEditor` accept HTML directly as `content`), so no
  # separate JSON<->HTML conversion step is needed on the Ruby side.
  class RichText < ActiveRecord::Base
    # How #to_plain_text separates elements: paragraph-level blocks get a blank line between
    # them, list items and table rows a single newline, and table cells a space.
    PARAGRAPH_TAGS = %w[
      p div h1 h2 h3 h4 h5 h6 blockquote pre figure figcaption ul ol table details
    ].freeze
    LINE_TAGS = %w[li tr summary].freeze
    CELL_TAGS = %w[td th].freeze
    # Private-use codepoint: not whitespace, so the collapse in #to_plain_text leaves it
    # alone, and Nokogiri accepts it in a text node (unlike NUL).
    BREAK = "\uE000"

    self.table_name = "domternal_rich_texts"

    belongs_to :record, polymorphic: true, touch: true
    has_many_attached :embeds

    before_validation :sanitize_body
    before_validation :attach_embedded_blobs

    delegate :blank?, :present?, :empty?, to: :to_plain_text

    def to_s
      body.to_s.html_safe # rubocop:disable Rails/OutputSafety -- sanitized in #sanitize_body before persistence
    end

    # Block-aware, like ActionText's plain text conversion: block boundaries and <br> become
    # newlines rather than being collapsed into spaces. Callers rely on this — line-oriented
    # content (one list item or answer per line) has to survive the round trip, and search
    # index columns built from rich text read far better with the structure kept.
    def to_plain_text
      html = body.to_s
      return "" if html.blank?

      fragment = Nokogiri::HTML5.fragment(html)
      # Breaks are marked with a sentinel rather than a real newline so that the whitespace
      # collapse below can't tell them apart from incidental newlines in the source markup.
      fragment.css("br").each { |node| node.replace(text_node(node, BREAK)) }
      fragment.css(*CELL_TAGS).each { |node| node.add_next_sibling(text_node(node, " ")) }
      fragment.css(*LINE_TAGS).each { |node| node.add_next_sibling(text_node(node, BREAK)) }
      fragment.css(*PARAGRAPH_TAGS).each { |node| node.add_next_sibling(text_node(node, BREAK * 2)) }

      fragment.text
        .gsub(/[^\S\n]+/, " ")  # spaces and tabs collapse; newlines in text are content
        .gsub(/ ?(#{BREAK}(?: ?#{BREAK})*) ?/o) { "\n" * Regexp.last_match(1).count(BREAK) }
        .gsub(/ *\n */, "\n")
        .gsub(/\n{3,}/, "\n\n")
        .strip
    end

    private

    def text_node(node, content)
      Nokogiri::XML::Text.new(content, node.document)
    end

    def sanitize_body
      return if body.blank?

      config = Rails::Domternal.configuration
      sanitizer_class = Rails::HTML::Sanitizer.best_supported_vendor.safe_list_sanitizer
      self.body = sanitizer_class.new.sanitize(
        body,
        tags: config.sanitizer_allowed_tags,
        attributes: config.sanitizer_allowed_attributes
      )
    end

    # Blob URLs embedded by the Domternal image extension's upload handler look like
    # /rails/active_storage/blobs/redirect/:signed_id/:filename (see
    # app/assets/javascripts/domternal/direct_upload.js). Extracting the signed_id lets us
    # attach the blob for lifecycle management (dependent: :destroy, backup/admin visibility)
    # without needing a custom attachment tag/model the way ActionText does.
    def attach_embedded_blobs
      return if body.blank?

      signed_ids = body.to_s.scan(%r{/rails/active_storage/blobs/(?:redirect|proxy)/([^/]+)/}).flatten.uniq
      blobs = signed_ids.filter_map { |signed_id| ActiveStorage::Blob.find_signed(signed_id) }

      # Only reassign when the set actually changed: `embeds=` replaces every attachment row
      # and re-runs Active Storage's identify pass (which downloads a chunk of each blob), so
      # doing it on every save of an unchanged body is needless work.
      return if blobs.map(&:id).to_set == embeds_blobs.map(&:id).to_set

      self.embeds = blobs
    end
  end
end
