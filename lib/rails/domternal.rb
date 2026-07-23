# frozen_string_literal: true

require_relative "domternal/version"
require_relative "domternal/configuration"
require_relative "domternal/extension_registry"
require_relative "domternal/attribute"

module Rails
  module Domternal
    class Error < StandardError; end

    class << self
      def configuration
        @configuration ||= Configuration.new
      end

      def configure
        yield configuration
      end

      def extension_registry
        @extension_registry ||= ExtensionRegistry.new
      end
    end
  end
end

require_relative "domternal/engine" if defined?(::Rails::Engine)
