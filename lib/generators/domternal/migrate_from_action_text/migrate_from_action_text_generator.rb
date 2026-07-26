# frozen_string_literal: true

require "rails/generators/active_record"

module Domternal
  module Generators
    # rails g domternal:migrate_from_action_text
    #
    # Copies every action_text_rich_texts row into domternal_rich_texts, rewriting the
    # <action-text-attachment> nodes that Domternal has no equivalent for. Writes a normal
    # timestamped migration so it runs through the usual deploy path and stays reversible.
    class MigrateFromActionTextGenerator < ::Rails::Generators::Base
      include ActiveRecord::Generators::Migration

      source_root File.expand_path("templates", __dir__)

      class_option :attachment_partials, type: :hash, default: {},
        desc: "Map of attachable class name to a method returning its replacement HTML, " \
          "e.g. --attachment-partials HtmlTable:content"

      def create_migration_file
        migration_template "migrate_action_text_to_domternal.rb.tt",
          "db/migrate/migrate_action_text_to_domternal.rb"
      end

      def show_notes
        say <<~NOTES, :green

          Review the generated migration before running it. It:

            * copies bodies verbatim (both use sanitized HTML, so no conversion is needed)
            * turns image attachments into <img> tags on Active Storage redirect URLs, which
              is the same markup the editor's upload handler writes
            * re-attaches the referenced blobs as Domternal::RichText embeds
            * leaves action_text_rich_texts untouched, so you can roll back

          Non-image attachables (ActionText::Attachable models of your own) are dropped unless
          you tell it what to render — see ATTACHABLE_REPLACEMENTS in the migration.
        NOTES
      end

      private

      def attachment_replacements
        options["attachment_partials"]
      end
    end
  end
end
