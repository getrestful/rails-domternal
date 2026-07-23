# Pin npm packages by running ./bin/importmap

pin "application"
pin "@hotwired/turbo-rails", to: "turbo.min.js"
pin "@hotwired/stimulus", to: "stimulus.min.js"
pin "@hotwired/stimulus-loading", to: "stimulus-loading.js"
pin_all_from "app/javascript/controllers", under: "controllers"

# rails-domternal
pin_all_from Rails::Domternal::Engine.root.join("app/assets/javascripts/domternal"), under: "domternal", preload: true
pin "@rails/activestorage", to: "activestorage.esm.js", preload: true
pin "@domternal/pm/", to: "https://esm.sh/@domternal/pm@latest/"
pin "@domternal/core", to: "https://esm.sh/@domternal/core@latest"
pin "@domternal/vanilla", to: "https://esm.sh/@domternal/vanilla@latest?external=@domternal/core", preload: false
pin "@domternal/extension-image", to: "https://esm.sh/@domternal/extension-image@latest?external=@domternal/core,@domternal/pm", preload: false
pin "@domternal/extension-table", to: "https://esm.sh/@domternal/extension-table@latest?external=@domternal/core,@domternal/pm", preload: false
pin "@domternal/extension-mention", to: "https://esm.sh/@domternal/extension-mention@latest?external=@domternal/core,@domternal/pm", preload: false
pin "@domternal/extension-markdown", to: "https://esm.sh/@domternal/extension-markdown@latest?external=@domternal/core,@domternal/pm", preload: false
pin "@domternal/extension-emoji", to: "https://esm.sh/@domternal/extension-emoji@latest?external=@domternal/core,@domternal/pm", preload: false
pin "@domternal/extension-math", to: "https://esm.sh/@domternal/extension-math@latest?external=@domternal/core,@domternal/pm", preload: false
pin "@domternal/extension-code-block-lowlight", to: "https://esm.sh/@domternal/extension-code-block-lowlight@latest?external=@domternal/core,@domternal/pm", preload: false
pin "@domternal/extension-toc", to: "https://esm.sh/@domternal/extension-toc@latest?external=@domternal/core,@domternal/pm", preload: false
pin "@domternal/extension-block-controls", to: "https://esm.sh/@domternal/extension-block-controls@latest?external=@domternal/core,@domternal/pm", preload: false
pin "@domternal/extension-details", to: "https://esm.sh/@domternal/extension-details@latest?external=@domternal/core,@domternal/pm", preload: false
