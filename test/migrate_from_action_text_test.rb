# frozen_string_literal: true

require "test_helper"
require "rails/generators"
require "generators/domternal/migrate_from_action_text/migrate_from_action_text_generator"

# Runs the generator, then loads and executes the migration it wrote against real rows.
class MigrateFromActionTextTest < ActiveSupport::TestCase
  DESTINATION = File.expand_path("../tmp/generator", __dir__)

  def setup
    FileUtils.rm_rf(DESTINATION)
    FileUtils.mkdir_p(DESTINATION)
  end

  def teardown
    super
    Object.send(:remove_const, :MigrateActionTextToDomternal) if defined?(MigrateActionTextToDomternal)
  end

  def run_migration(attachment_partials: {})
    args = []
    unless attachment_partials.empty?
      args << "--attachment-partials"
      attachment_partials.each { |k, v| args << "#{k}:#{v}" }
    end
    Domternal::Generators::MigrateFromActionTextGenerator.start(
      args, destination_root: DESTINATION, shell: Thor::Shell::Basic.new
    )

    path = Dir["#{DESTINATION}/db/migrate/*_migrate_action_text_to_domternal.rb"].sole
    load path
    capture_output { MigrateActionTextToDomternal.new.up }
  end

  def capture_output
    original = $stdout
    $stdout = StringIO.new
    yield
  ensure
    $stdout = original
  end

  # Bare model on the same table: ActionText::RichText would render the body through its
  # Content serializer, which downloads attachment blobs we never wrote files for.
  class RawRichText < ActiveRecord::Base
    self.table_name = "action_text_rich_texts"
  end

  def legacy(post, name: "body", body:)
    RawRichText.create!(record_type: post.class.name, record_id: post.id, name: name, body: body)
  end

  def test_copies_plain_bodies_verbatim
    post = Post.create!(title: "Post")
    legacy(post, body: "<p>Hello <strong>World</strong>!</p>")

    run_migration

    assert_equal "<p>Hello <strong>World</strong>!</p>", post.reload.body.to_s
  end

  def test_converts_image_attachment_to_img_tag
    post = Post.create!(title: "Post")
    blob = create_blob(filename: "photo.png")
    legacy(post, body: <<~HTML)
      <action-text-attachment sgid="#{blob.attachable_sgid}" content-type="image/png" filename="photo.png"></action-text-attachment>
      <p>After</p>
    HTML

    run_migration

    body = post.reload.body.to_s
    assert_includes body, "/rails/active_storage/blobs/redirect/#{blob.signed_id}/photo.png"
    assert_includes body, %(alt="photo.png")
    refute_includes body, "action-text-attachment"
    assert_includes body, "<p>After</p>"
  end

  def test_reattaches_blobs_as_embeds
    post = Post.create!(title: "Post")
    blob = create_blob
    legacy(post, body: %(<action-text-attachment sgid="#{blob.attachable_sgid}" content-type="image/png" filename="photo.png"></action-text-attachment>))

    run_migration

    assert_equal [ blob.id ], post.reload.body.embeds.map(&:blob_id)
  end

  def test_wraps_captioned_images_in_a_figure
    post = Post.create!(title: "Post")
    blob = create_blob
    legacy(post, body: %(<action-text-attachment sgid="#{blob.attachable_sgid}" content-type="image/png" filename="photo.png" caption="A caption"></action-text-attachment>))

    run_migration

    body = post.reload.body.to_s
    assert_includes body, "<figure>"
    assert_includes body, "<figcaption>A caption</figcaption>"
  end

  def test_drops_unmapped_attachables
    post = Post.create!(title: "Post")
    table = LegacyTable.create!(content: "<table><tbody><tr><td>A</td></tr></tbody></table>")
    legacy(post, body: %(<p>Before</p><action-text-attachment sgid="#{table.attachable_sgid}"></action-text-attachment>))

    run_migration

    body = post.reload.body.to_s
    assert_includes body, "<p>Before</p>"
    refute_includes body, "action-text-attachment"
    refute_includes body, "<table"
  end

  def test_inlines_mapped_attachables
    post = Post.create!(title: "Post")
    table = LegacyTable.create!(content: "<table><tbody><tr><td>A</td></tr></tbody></table>")
    legacy(post, body: %(<action-text-attachment sgid="#{table.attachable_sgid}"></action-text-attachment>))

    run_migration(attachment_partials: { "LegacyTable" => "content" })

    assert_includes post.reload.body.to_s, "<td>A</td>"
  end

  def test_survives_an_attachable_class_that_no_longer_exists
    post = Post.create!(title: "Post")
    table = LegacyTable.create!(content: "x")
    sgid = table.attachable_sgid
    legacy(post, body: %(<p>Kept</p><action-text-attachment sgid="#{sgid}"></action-text-attachment>))

    gone = LegacyTable
    Object.send(:remove_const, :LegacyTable)
    begin
      run_migration
    ensure
      Object.const_set(:LegacyTable, gone)
    end

    assert_includes post.reload.body.to_s, "<p>Kept</p>"
  end

  def test_is_idempotent
    post = Post.create!(title: "Post")
    legacy(post, body: "<p>Once</p>")

    run_migration
    teardown_constant
    run_migration

    assert_equal 1, Domternal::RichText.where(record: post, name: "body").count
  end

  def test_preserves_timestamps
    post = Post.create!(title: "Post")
    legacy(post, body: "<p>x</p>")
    created = 3.days.ago.change(usec: 0)
    RawRichText.update_all(created_at: created)

    run_migration

    assert_equal created.to_i, post.reload.body.created_at.to_i
  end

  def test_leaves_the_legacy_table_intact
    post = Post.create!(title: "Post")
    legacy(post, body: "<p>x</p>")

    run_migration

    assert_equal 1, ActionText::RichText.count
  end

  private

  def teardown_constant
    Object.send(:remove_const, :MigrateActionTextToDomternal) if defined?(MigrateActionTextToDomternal)
  end
end
