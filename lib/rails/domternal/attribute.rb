# frozen_string_literal: true

require "active_support/concern"

module Rails
  module Domternal
    module Attribute
      extend ActiveSupport::Concern

      class_methods do
        # Declares a dependent Domternal::RichText association, mirroring ActionText's
        # `has_rich_text`. Example:
        #
        #     class Post < ApplicationRecord
        #       has_rich_domternal :body, extensions: %i[starter_kit image table], toolbar: :full
        #     end
        #
        #     post.body = "<p>Hello <strong>World</strong>!</p>"
        #     post.body.to_s
        #
        # `extensions:` and `toolbar:` are per-attribute overrides of
        # Rails::Domternal.configuration.default_extensions/toolbar; both are rendered into
        # the `domternal_area` form tag's data attributes so the client knows what to load.
        def has_rich_domternal(name, extensions: nil, toolbar: nil)
          extensions&.each { |extension| Rails::Domternal.extension_registry.fetch!(extension) }

          class_eval <<-CODE, __FILE__, __LINE__ + 1
            def #{name}
              rich_domternal_#{name} || build_rich_domternal_#{name}
            end

            def #{name}?
              rich_domternal_#{name}.present?
            end

            def #{name}=(body)
              self.#{name}.body = body
            end
          CODE

          has_one :"rich_domternal_#{name}", -> { where(name: name) },
            class_name: "Domternal::RichText", as: :record, inverse_of: :record,
            autosave: true, dependent: :destroy

          scope :"with_rich_domternal_#{name}", -> { includes("rich_domternal_#{name}") }

          domternal_attributes[name.to_sym] = {
            extensions: extensions || Rails::Domternal.configuration.default_extensions,
            toolbar: toolbar.nil? ? Rails::Domternal.configuration.toolbar : toolbar
          }
        end

        # Eager loads all dependent Domternal::RichText models in bulk.
        def with_all_rich_domternal
          includes(domternal_association_names)
        end

        def domternal_association_names
          reflect_on_all_associations(:has_one).collect(&:name).select { |n| n.start_with?("rich_domternal_") }
        end

        # Options passed to `has_rich_domternal`, keyed by attribute name. Read by
        # Domternal::TagHelper to fill in the `domternal_area` tag's config without the
        # caller having to repeat them.
        def domternal_attributes
          @domternal_attributes ||= {}
        end
      end
    end
  end
end
