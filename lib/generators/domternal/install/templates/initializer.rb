# Configuration for rails-domternal, a Domternal (https://github.com/domternal/domternal)
# editor integration shaped like ActionText. See Rails::Domternal::Configuration for the
# full list of options.
Rails::Domternal.configure do |config|
  # Symbolic extension keys resolved client-side by app/assets/javascripts/domternal/extensions.js
  # and validated server-side by Rails::Domternal::ExtensionRegistry. Override per-attribute with
  # `has_rich_domternal :body, extensions: %i[starter_kit image table]`.
  # config.default_extensions = %i[starter_kit image]

  # :full, :minimal, :notion, or false — overridable per has_rich_domternal/domternal_area call.
  # config.toolbar = :full

  # :light, :dark, or :auto
  # config.theme = :light

  # config.allowed_mime_types = %w[image/png image/jpeg image/gif image/webp image/svg+xml image/avif]
  # config.max_file_size = 10.megabytes

  # Tags/attributes let through the safelist sanitizer applied to incoming bodies before they're
  # persisted. Widen this if you enable extensions (e.g. extension-table, extension-details) that
  # introduce markup not covered by the defaults.
  # config.sanitizer_allowed_tags += %w[]
  # config.sanitizer_allowed_attributes += %w[]

  # Column types for the domternal_rich_texts table, read only when the CreateDomternalTables
  # migration runs — set them BEFORE `bin/rails db:migrate`. Both default to your
  # config.generators primary_key_type, then to Rails' defaults (:primary_key / :bigint).
  #
  # `record_id` stores the primary key of every model declaring has_rich_domternal, so if those
  # models don't all share one key type — a uuid-pk model next to a bigint-pk one — neither
  # :uuid nor :bigint fits and you want :string.
  # config.primary_key_type = :uuid
  # config.record_id_type = :string
end
