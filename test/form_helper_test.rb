# frozen_string_literal: true

require "test_helper"

module ViewBuilder
  def build_view
    controller = ActionController::Base.new
    controller.request = ActionDispatch::TestRequest.create
    controller.view_context
  end
end

class FormHelperTest < ActiveSupport::TestCase
  include ViewBuilder

  def setup
    @post = Post.create!(title: "Post", body: "<p>Hi</p>")
    @view = build_view
  end

  def form_for(record, **options, &block)
    @view.form_with(model: record, url: "/posts", **options, &block)
  end

  def hidden_value(html)
    Nokogiri::HTML5.fragment(html).at_css(%(input[name="post[body]"]))["value"]
  end

  def test_domternal_area_renders_editor_and_hidden_input
    html = form_for(@post) { |f| f.domternal_area(:body) }

    assert_match(/<domternal-editor/, html)
    assert_match(/<input[^>]+type="hidden"[^>]+name="post\[body\]"/, html)
  end

  def test_editor_is_linked_to_its_input
    html = form_for(@post) { |f| f.domternal_area(:body) }
    input_id = html[/<domternal-editor[^>]*input="([^"]+)"/, 1]

    refute_nil input_id
    assert_match(/id="#{Regexp.escape(input_id)}"/, html)
  end

  def test_current_body_is_the_hidden_input_value
    html = form_for(@post) { |f| f.domternal_area(:body) }

    assert_equal "<p>Hi</p>", hidden_value(html)
  end

  # RichText#to_s is html_safe, and Rails skips escaping html_safe strings even in attributes,
  # so an unescaped body containing a quote would close value="…" early.
  def test_a_body_containing_quotes_survives_the_round_trip
    @post.update!(body: %(<p>He said "hi" to me</p>))
    html = form_for(@post.reload) { |f| f.domternal_area(:body) }

    assert_includes html, "&quot;"
    assert_equal %(<p>He said "hi" to me</p>), hidden_value(html)
  end

  def test_a_body_cannot_inject_attributes_into_the_hidden_field
    @post.update!(body: %(<p>x" onfocus="alert(1)</p>))
    html = form_for(@post.reload) { |f| f.domternal_area(:body) }

    field = Nokogiri::HTML5.fragment(html).at_css(%(input[name="post[body]"]))
    assert_nil field["onfocus"], "body content leaked out of value= into a real attribute"
    assert_equal %(<p>x" onfocus="alert(1)</p>), field["value"]
  end

  def test_per_attribute_extensions_and_toolbar_reach_the_tag
    html = form_for(@post) { |f| f.domternal_area(:summary) }

    assert_match(/data-extensions="starter_kit"/, html)
    assert_match(/data-toolbar="minimal"/, html)
  end

  def test_defaults_come_from_configuration
    html = form_for(@post) { |f| f.domternal_area(:body) }

    assert_match(/data-extensions="starter_kit image"/, html)
    assert_match(/data-toolbar="full"/, html)
  end

  def test_upload_endpoints_are_wired_to_active_storage
    html = form_for(@post) { |f| f.domternal_area(:body) }

    assert_match(/data-direct-upload-url="[^"]*\/rails\/active_storage\/direct_uploads"/, html)
    assert_match(/data-blob-url-template="[^"]*:signed_id[^"]*"/, html)
  end

  def test_explicit_options_override_the_attribute_declaration
    html = form_for(@post) { |f| f.domternal_area(:body, toolbar: :notion) }

    assert_match(/data-toolbar="notion"/, html)
  end
end

class SimpleFormInputTest < ActiveSupport::TestCase
  include ViewBuilder
  def setup
    @post = Post.create!(title: "Post", body: "<p>Hi</p>")
    @view = build_view
  end

  def test_input_is_registered_when_simple_form_is_present
    assert defined?(::SimpleForm), "simple_form should be loaded in the test app"
    assert Object.const_defined?(:DomternalAreaInput),
           "the engine should register DomternalAreaInput when simple_form is present"
  end

  def test_as_domternal_area_renders_the_editor
    html = @view.simple_form_for(@post, url: "/posts") { |f| f.input(:body, as: :domternal_area) }

    assert_match(/<domternal-editor/, html)
    assert_match(/name="post\[body\]"/, html)
  end
end
