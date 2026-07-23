# frozen_string_literal: true

module Rails
  module Domternal
    # Ruby-side mirror of app/assets/javascripts/domternal/extensions.js — kept in sync
    # so `has_rich_domternal extensions: [...]` can fail fast on typos instead of only
    # erroring in the browser console.
    class ExtensionRegistry
      UnknownExtensionError = Class.new(StandardError)

      def initialize
        @known = %i[
          starter_kit image table mention markdown emoji math
          code_block toc block_controls details
        ].to_set
      end

      def register(name)
        @known << name.to_sym
      end

      def known?(name)
        @known.include?(name.to_sym)
      end

      def fetch!(name)
        unless known?(name)
          raise UnknownExtensionError,
            "Unknown Domternal extension #{name.inspect}. Known extensions: #{@known.to_a.sort.inspect}. " \
            "Register custom ones with Rails::Domternal.extension_registry.register(:my_extension) " \
            "and app/assets/javascripts/domternal/extensions.js's registerExtension()."
        end
        name.to_sym
      end
    end
  end
end
