# frozen_string_literal: true

# Loaded only when the host app has simple_form (see Engine's "domternal.simple_form"
# initializer). simple_form resolves `as: :domternal_area` by constantizing
# "DomternalAreaInput" at the top level, which is why this isn't namespaced.
#
#   <%= simple_form_for @post do |f| %>
#     <%= f.input :body, as: :domternal_area %>
#   <% end %>
#
# An app-defined app/inputs/domternal_area_input.rb takes precedence.
class DomternalAreaInput < SimpleForm::Inputs::Base
  def input(wrapper_options = nil)
    merged_input_options = merge_wrapper_options(input_html_options, wrapper_options)
    @builder.domternal_area(attribute_name, merged_input_options)
  end
end
