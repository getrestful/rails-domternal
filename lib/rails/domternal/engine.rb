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

      # Opt-in by presence: apps using simple_form get `as: :domternal_area` for free, apps
      # without it never load the input. Runs after initialization so an app's own
      # app/inputs/domternal_area_input.rb wins.
      initializer "domternal.simple_form" do |app|
        app.config.after_initialize do
          next unless defined?(::SimpleForm)
          next if Object.const_defined?(:DomternalAreaInput)

          require "rails/domternal/simple_form_input"
        end
      end
    end
  end
end
