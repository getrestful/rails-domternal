# frozen_string_literal: true

module Domternal
  # Holds the HTML body + Active Storage embeds for a single has_rich_domternal attribute.
  # Body is stored as the same sanitized HTML the Domternal editor renders/re-parses
  # (Domternal's `Editor`/`DomternalEditor` accept HTML directly as `content`), so no
  # separate JSON<->HTML conversion step is needed on the Ruby side.
  class RichText < ActiveRecord::Base
    self.table_name = "domternal_rich_texts"

    belongs_to :record, polymorphic: true, touch: true
    has_many_attached :embeds

    before_validation :sanitize_body
    before_validation :attach_embedded_blobs

    delegate :blank?, :present?, :empty?, to: :to_plain_text

    def to_s
      body.to_s.html_safe # rubocop:disable Rails/OutputSafety -- sanitized in #sanitize_body before persistence
    end

    def to_plain_text
      body.to_s.gsub(/<[^>]*>/, " ").gsub(/\s+/, " ").strip
    end

    private

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
      self.embeds = signed_ids.filter_map { |signed_id| ActiveStorage::Blob.find_signed(signed_id) }
    end
  end
end
