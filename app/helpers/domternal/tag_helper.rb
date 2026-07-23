# frozen_string_literal: true

require "active_support/core_ext/object/try"
require "action_view/helpers/tags/placeholderable"

module Domternal
  module TagHelper
    cattr_accessor(:id, instance_accessor: false) { 0 }

    # Renders a hidden field plus a <domternal-editor> custom element that mounts the
    # editor and keeps the hidden field's value in sync on every change — the same shape
    # as ActionText's rich_textarea_tag/<trix-editor> pair.
    #
    # #### Options
    # *   `:extensions` - symbolic extension names (see Rails::Domternal::ExtensionRegistry).
    #     Defaults to the attribute's `has_rich_domternal` declaration, or
    #     `Rails::Domternal.configuration.default_extensions`.
    # *   `:toolbar` - :full, :minimal, :notion, or false. Same defaulting as `:extensions`.
    # *   `[:data][:direct_upload_url]` - defaults to `rails_direct_uploads_url`.
    # *   `[:data][:blob_url_template]` - defaults to `rails_service_blob_url(":signed_id", ":filename")`.
    def domternal_area_tag(name, value = nil, options = {}, &block)
      value = capture(&block) if value.nil? && block_given?
      options = options.symbolize_keys
      form = options.delete(:form)
      extensions = Array(options.delete(:extensions) || Rails::Domternal.configuration.default_extensions)
      toolbar = options.key?(:toolbar) ? options.delete(:toolbar) : Rails::Domternal.configuration.toolbar

      options[:input] ||= "domternal_input_#{Domternal::TagHelper.id += 1}"
      options[:class] ||= "domternal-content"

      options[:data] ||= {}
      options[:data][:direct_upload_url] ||= main_app.rails_direct_uploads_url
      options[:data][:blob_url_template] ||= main_app.rails_service_blob_url(":signed_id", ":filename")
      options[:data][:extensions] ||= extensions.join(" ")
      options[:data][:toolbar] ||= toolbar.to_s
      options[:data][:theme] ||= Rails::Domternal.configuration.theme.to_s
      options[:data][:max_file_size] ||= Rails::Domternal.configuration.max_file_size
      options[:data][:allowed_mime_types] ||= Rails::Domternal.configuration.allowed_mime_types.join(" ")

      editor_tag = content_tag("domternal-editor", "", options)
      input_tag = hidden_field_tag(name, value.to_s, id: options[:input], form: form)

      input_tag + editor_tag
    end

    def domternal_content(value)
      content_tag(:div, value.to_s.html_safe, class: "domternal-content") # rubocop:disable Rails/OutputSafety -- sanitized by Domternal::RichText before persistence
    end
  end
end

module ActionView::Helpers
  class Tags::Domternal < Tags::Base
    include Tags::Placeholderable

    delegate :dom_id, to: ActionView::RecordIdentifier

    def render(&block)
      options = @options.stringify_keys
      add_default_name_and_field(options)
      options["input"] ||= dom_id(object, [options["id"], :domternal_input].compact.join("_")) if object

      attribute_options = object.class.try(:domternal_attributes)&.dig(@method_name.to_sym) || {}
      options["extensions"] ||= attribute_options[:extensions]
      options["toolbar"] = attribute_options[:toolbar] unless options.key?("toolbar")

      html_tag = @template_object.domternal_area_tag(
        options.delete("name"), options.fetch("value") { value }, options.except("value"), &block
      )
      error_wrapping(html_tag)
    end
  end

  module FormHelper
    # Returns a domternal_area_tag for the given object/method — see FormBuilder#domternal_area.
    def domternal_area(object_name, method, options = {}, &block)
      Tags::Domternal.new(object_name, method, self, options).render(&block)
    end
  end

  class FormBuilder
    # Wraps ActionView::Helpers::FormHelper#domternal_area for form builders:
    #
    #     <%= form_with model: @post do |f| %>
    #       <%= f.domternal_area :body %>
    #     <% end %>
    def domternal_area(method, options = {}, &block)
      @template.domternal_area(@object_name, method, objectify_options(options), &block)
    end
  end
end
