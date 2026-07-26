# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)

require "rails"
require "active_record/railtie"
require "active_storage/engine"
require "action_text/engine"
require "action_controller/railtie"
require "action_view/railtie"

require "simple_form"
require "rails/domternal"

# Minimal host application so the engine's initializers, helpers and models load the same
# way they do in a real app.
class TestApplication < Rails::Application
  config.root = File.expand_path("dummy", __dir__)
  config.eager_load = false
  config.logger = Logger.new(IO::NULL)
  config.secret_key_base = "domternal-test-secret"
  config.active_storage.service = :test
  config.active_storage.service_configurations = {
    "test" => { "service" => "Disk", "root" => File.expand_path("../tmp/storage", __dir__) }
  }
  config.hosts.clear
end

Rails.application.routes.draw do
  resources :posts
  # Active Storage routes the tag helper builds upload URLs from.
  get "/rails/active_storage/blobs/redirect/:signed_id/*filename" => "active_storage/blobs/redirect#show",
      as: :rails_service_blob
  post "/rails/active_storage/direct_uploads" => "active_storage/direct_uploads#create",
       as: :rails_direct_uploads
end

Rails.application.initialize!

SimpleForm.setup { |config| config.default_wrapper = :default }

# Real apps get this from Rails' :add_mounted_helpers initializer; this bare test app
# finalizes ActionController::Base too early to pick it up.
ActionController::Base.include(Rails.application.routes.mounted_helpers)

Rails.application.routes.default_url_options[:host] = "test.host"

ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")

ActiveRecord::Schema.verbose = false
ActiveRecord::Schema.define do
  create_table :domternal_rich_texts do |t|
    t.string :name, null: false
    t.text :body
    t.string :record_type, null: false
    t.string :record_id, null: false
    t.timestamps
    t.index %i[record_type record_id name], unique: true
  end

  create_table :action_text_rich_texts do |t|
    t.string :name, null: false
    t.text :body
    t.string :record_type, null: false
    t.string :record_id, null: false
    t.timestamps
    t.index %i[record_type record_id name], unique: true
  end

  create_table :legacy_tables do |t|
    t.text :content
  end

  create_table :posts do |t|
    t.string :title
    t.timestamps
  end

  create_table :active_storage_blobs do |t|
    t.string :key, null: false
    t.string :filename, null: false
    t.string :content_type
    t.text :metadata
    t.string :service_name, null: false
    t.bigint :byte_size, null: false
    t.string :checksum
    t.datetime :created_at, null: false
    t.index [ :key ], unique: true
  end

  create_table :active_storage_attachments do |t|
    t.string :name, null: false
    t.string :record_type, null: false
    t.string :record_id, null: false
    t.bigint :blob_id, null: false
    t.datetime :created_at, null: false
  end

  create_table :active_storage_variant_records do |t|
    t.bigint :blob_id, null: false
    t.string :variation_digest, null: false
  end
end

class LegacyTable < ActiveRecord::Base
  include ActionText::Attachable
end

class Post < ActiveRecord::Base
  has_rich_domternal :body
  has_rich_domternal :summary, extensions: %i[starter_kit], toolbar: :minimal
end

require "minitest/autorun"

class ActiveSupport::TestCase
  def teardown
    Domternal::RichText.delete_all
    ActionText::RichText.delete_all
    LegacyTable.delete_all
    Post.delete_all
    ActiveStorage::Attachment.delete_all
    ActiveStorage::Blob.delete_all
  end

  def create_blob(filename: "photo.png", content_type: "image/png")
    ActiveStorage::Blob.create_and_upload!(
      io: StringIO.new("fake image bytes"), filename: filename,
      content_type: content_type, identify: false
    )
  end
end
