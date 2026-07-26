# frozen_string_literal: true

require "test_helper"

class RichTextTest < ActiveSupport::TestCase
  def test_it_has_a_version_number
    refute_nil ::Rails::Domternal::VERSION
  end

  def test_assigning_and_reading_back_a_body
    post = Post.create!(title: "Hi", body: "<p>Hello <strong>World</strong>!</p>")
    assert_equal "<p>Hello <strong>World</strong>!</p>", post.reload.body.to_s
  end

  def test_sanitizes_disallowed_markup
    post = Post.create!(title: "Hi", body: "<p>ok</p><script>alert(1)</script>")
    refute_includes post.reload.body.to_s, "script"
  end
end

class EmbedsTest < ActiveSupport::TestCase
  def image_html(blob)
    %(<p><img src="/rails/active_storage/blobs/redirect/#{blob.signed_id}/photo.png" alt="p"></p>)
  end

  def test_attaches_blobs_referenced_in_the_body
    blob = create_blob
    post = Post.create!(title: "t", body: image_html(blob))
    assert_equal [blob.id], post.reload.body.embeds.map(&:blob_id)
  end

  def test_detaches_blobs_removed_from_the_body
    blob = create_blob
    post = Post.create!(title: "t", body: image_html(blob))
    post.update!(body: "<p>gone</p>")
    assert_empty post.reload.body.embeds
  end

  def test_resaving_an_unchanged_body_does_not_churn_attachments
    blob = create_blob
    post = Post.create!(title: "t", body: image_html(blob))
    attachment_id = post.reload.body.embeds.sole.id

    post.body.touch
    post.reload.body.save!

    assert_equal attachment_id, post.reload.body.embeds.sole.id
  end
end

class ConfigurationTest < ActiveSupport::TestCase
  def test_key_types_default_to_nil_so_the_migration_can_fall_back
    config = Rails::Domternal::Configuration.new
    assert_nil config.primary_key_type
    assert_nil config.record_id_type
  end

  def test_key_types_are_settable
    config = Rails::Domternal::Configuration.new
    config.primary_key_type = :uuid
    config.record_id_type = :string

    assert_equal :uuid, config.primary_key_type
    assert_equal :string, config.record_id_type
  end

  def test_unknown_extensions_are_rejected_at_declaration_time
    assert_raises(Rails::Domternal::ExtensionRegistry::UnknownExtensionError) do
      Class.new(ActiveRecord::Base) do
        self.table_name = "posts"
        has_rich_domternal :body, extensions: %i[not_a_real_extension]
      end
    end
  end
end
