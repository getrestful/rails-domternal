class Post < ApplicationRecord
  has_rich_domternal :body, extensions: %i[starter_kit image table]
  has_rich_domternal :internal_notes, extensions: %i[starter_kit block_controls toc], toolbar: :notion
end
