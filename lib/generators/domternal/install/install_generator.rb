# frozen_string_literal: true

require "pathname"

module Domternal
  module Generators
    # rails g domternal:install
    #
    # Detects whether the host app uses importmap-rails or a Node/Bun bundler
    # (jsbundling-rails, vite_rails, ...) and wires up the JS accordingly, mirroring
    # ActionText's install generator (lib/generators/action_text/install/install_generator.rb).
    class InstallGenerator < ::Rails::Generators::Base
      source_root File.expand_path("templates", __dir__)
      source_paths << File.expand_path("../../../../app/assets/javascripts", __dir__)

      # @domternal/vanilla and every @domternal/extension-* package declare @domternal/core
      # (and, transitively, @domternal/pm — the ProseMirror re-export used for plugin
      # identity) as peer dependencies. esm.sh only emits real `import` statements for a
      # peer (rather than inlining its own private copy) when it's passed via `?external=`,
      # so every consumer below must externalize the same set — otherwise two different
      # copies of ProseMirror's Plugin/PluginKey classes end up on the page and construction
      # fails with "Adding different instances of a keyed plugin". @domternal/pm's own
      # subpaths (state, view, model, ...) are covered by a single prefix pin instead of
      # being listed one by one.
      CORE_PACKAGE = "@domternal/core"
      PM_PACKAGE = "@domternal/pm"

      NPM_PACKAGES = {
        CORE_PACKAGE => nil,
        "@domternal/vanilla" => [CORE_PACKAGE],
        "@domternal/extension-image" => [CORE_PACKAGE, PM_PACKAGE]
      }.freeze

      OPTIONAL_NPM_PACKAGES = %w[
        @domternal/extension-table @domternal/extension-mention @domternal/extension-markdown
        @domternal/extension-emoji @domternal/extension-math @domternal/extension-code-block-lowlight
        @domternal/extension-toc @domternal/extension-block-controls @domternal/extension-details
      ].index_with { [CORE_PACKAGE, PM_PACKAGE] }.freeze

      class_option :npm_version, type: :string, default: "latest",
        desc: "Version/dist-tag used when pinning @domternal/* packages"

      class_option :stylesheet, type: :string, default: nil, enum: %w[css tailwind],
        desc: "Format for the generated content typography stylesheet. Defaults to " \
          "autodetecting app/assets/tailwind/application.css (tailwindcss-rails)."

      def create_initializer
        template "initializer.rb", "config/initializers/domternal.rb"
      end

      def create_stylesheet
        template "domternal.css.erb", "app/assets/stylesheets/domternal.css"
        say <<~INSTRUCTIONS, :green
          Add `<%= stylesheet_link_tag "domternal" %>` to your layout (next to your
          application stylesheet tag) to load the Domternal theme and editor styles.
        INSTRUCTIONS

        create_content_stylesheet
      end

      def create_migrations
        rails_command "railties:install:migrations FROM=active_storage,domternal", inline: true
      end

      def wire_up_javascript
        if using_importmap?
          wire_up_importmap
        elsif using_jsbundling?
          wire_up_jsbundling
        else
          say <<~INSTRUCTIONS, :yellow
            Could not detect importmap-rails or a package.json — add the Domternal JS
            yourself. See #{__dir__}/../../../../README.md for both approaches.
          INSTRUCTIONS
        end
      end

      def show_readme
        say <<~INSTRUCTIONS, :green

          Domternal is installed. Next steps:

            1. bin/rails db:migrate
            2. In a model:      has_rich_domternal :body
            3. In a form:       <%= form.domternal_area :body %>
            4. To render:       <%= domternal_content @post.body %>
        INSTRUCTIONS
      end

      private

      def npm_version
        options["npm_version"]
      end

      def using_importmap?
        Pathname(destination_root).join("config/importmap.rb").exist?
      end

      def using_jsbundling?
        Pathname(destination_root).join("package.json").exist?
      end

      def tailwind_stylesheet?
        options["stylesheet"] == "tailwind" ||
          (options["stylesheet"].nil? && tailwind_entry_path.exist?)
      end

      def tailwind_entry_path
        Pathname(destination_root).join("app/assets/tailwind/application.css")
      end

      def create_content_stylesheet
        if tailwind_stylesheet?
          template "domternal_content.tailwind.css.erb", "app/assets/tailwind/domternal_content.css"
          import_line = %(@import "./domternal_content.css";\n)
          if tailwind_entry_path.exist?
            append_to_file tailwind_entry_path.to_s, import_line unless
              tailwind_entry_path.read.include?(import_line.strip)
            say "Generated app/assets/tailwind/domternal_content.css (Tailwind @apply) and " \
              "imported it into application.css — it's built into your existing tailwind.css, " \
              "no extra <link> tag needed.", :green
          else
            say 'Generated app/assets/tailwind/domternal_content.css — add ' \
              '`@import "./domternal_content.css";` to your Tailwind entrypoint yourself ' \
              "(no app/assets/tailwind/application.css found to wire it into automatically).", :yellow
          end
        else
          template "domternal_content.css.erb", "app/assets/stylesheets/domternal_content.css"
          say 'Add `<%= stylesheet_link_tag "domternal_content" %>` to your layout to load ' \
            "the generated content typography.", :green
        end
      end

      def using_bun?
        using_jsbundling? && Pathname(destination_root).join("bun.config.js").exist?
      end

      def wire_up_importmap
        importmap_path = Pathname(destination_root).join("config/importmap.rb")

        pins = +"\n# rails-domternal\n"
        pins << %(pin_all_from Rails::Domternal::Engine.root.join("app/assets/javascripts/domternal"), under: "domternal", preload: true\n)
        pins << %(pin "@rails/activestorage", to: "activestorage.esm.js", preload: true\n) unless
          importmap_path.read.include?('"@rails/activestorage"')

        pins << %(pin "#{PM_PACKAGE}/", to: "https://esm.sh/#{PM_PACKAGE}@#{npm_version}/"\n)

        all_packages.each do |package, externals|
          url = "https://esm.sh/#{package}@#{npm_version}"
          url += "?external=#{externals.join(",")}" if externals.present?
          preload = package == CORE_PACKAGE
          pins << %(pin "#{package}", to: "#{url}"#{preload ? "" : ", preload: false"}\n)
        end

        append_to_file importmap_path.to_s, pins
        say "Pinned domternal + @domternal/* packages (via esm.sh) in config/importmap.rb", :green

        application_js = Pathname(destination_root).join("app/javascript/application.js")
        if application_js.exist?
          append_to_file application_js.to_s, %(import "domternal"\n) unless
            application_js.read.include?('import "domternal"')
        else
          say 'Add `import "domternal"` to your JS entrypoint.', :yellow
        end
      end

      def all_packages
        NPM_PACKAGES.merge(OPTIONAL_NPM_PACKAGES)
      end

      def wire_up_jsbundling
        say "Installing JavaScript dependencies", :green
        packages = (all_packages.keys + ["@domternal/theme"]).map { |p| "#{p}@#{npm_version}" }
        if using_bun?
          run "bun add #{packages.join(" ")}"
        else
          run "npm install #{packages.join(" ")}"
        end

        directory "domternal", "app/javascript/domternal"

        destination = Pathname(destination_root)
        application_js = destination.join("app/javascript/application.js")
        if application_js.exist?
          append_to_file application_js.to_s, %(\nimport "domternal/index"\n)
        else
          say "Add `import \"domternal/index\"` to your JS entrypoint.", :yellow
        end
      end
    end
  end
end
