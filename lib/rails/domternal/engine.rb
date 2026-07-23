# frozen_string_literal: true

require "rails/engine"

module Rails
  module Domternal
    class Engine < ::Rails::Engine
      isolate_namespace Rails::Domternal
      engine_name "domternal"

      config.domternal = Rails::Domternal.configuration

      initializer "domternal.assets" do |app|
        if app.config.respond_to?(:assets)
          app.config.assets.paths << root.join("app/assets/javascripts")
          app.config.assets.precompile += %w[domternal/index.js]
        end
      end

      initializer "domternal.active_storage" do
        require "active_storage/engine"
      end

      initializer "domternal.helper" do
        ActiveSupport.on_load(:action_controller_base) do
          helper ::Domternal::TagHelper
        end
      end

      initializer "domternal.attribute" do
        ActiveSupport.on_load(:active_record) do
          include Rails::Domternal::Attribute
        end
      end
    end
  end
end
