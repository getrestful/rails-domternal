class Post < ApplicationRecord
  has_rich_domternal :body, extensions: %i[starter_kit image table]
end
