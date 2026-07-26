class CreateDomternalTables < ActiveRecord::Migration[7.1]
  def change
    create_table :domternal_rich_texts, id: primary_key_type do |t|
      t.string :name, null: false
      t.text :body
      t.references :record, null: false, polymorphic: true, index: false, type: record_id_type

      t.timestamps

      t.index [ :record_type, :record_id, :name ], name: "index_domternal_rich_texts_uniqueness", unique: true
    end
  end

  private

  def primary_key_type
    Rails::Domternal.configuration.primary_key_type || generators_primary_key_type || :primary_key
  end

  # `record_id` has to hold the primary key of every model that declares has_rich_domternal.
  # An app whose models don't all share one key type (say uuid alongside bigint) needs
  # :string here — see config.record_id_type in config/initializers/domternal.rb.
  def record_id_type
    Rails::Domternal.configuration.record_id_type || generators_primary_key_type || :bigint
  end

  def generators_primary_key_type
    config = Rails.configuration.generators
    config.options[config.orm][:primary_key_type]
  end
end
