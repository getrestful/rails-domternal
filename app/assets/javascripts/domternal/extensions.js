// Symbolic extension names -> lazy-loaded Domternal extensions. Kept in sync with
// Rails::Domternal::ExtensionRegistry (lib/rails/domternal/extension_registry.rb), which
// validates `has_rich_domternal extensions: [...]` server-side against the same names.
const registry = new Map([
  ["starter_kit", async () => (await import("@domternal/core")).StarterKit],
  ["image", async (options) => {
    const { Image } = await import("@domternal/extension-image")
    return Image.configure(options.image || {})
  }],
  ["table", async () => {
    const { Table, TableRow, TableCell, TableHeader } = await import("@domternal/extension-table")
    return [Table, TableRow, TableCell, TableHeader]
  }],
  ["mention", async () => (await import("@domternal/extension-mention")).Mention],
  ["markdown", async () => (await import("@domternal/extension-markdown")).Markdown],
  ["emoji", async () => (await import("@domternal/extension-emoji")).Emoji],
  ["math", async () => (await import("@domternal/extension-math")).Math],
  ["code_block", async () => (await import("@domternal/extension-code-block-lowlight")).CodeBlockLowlight],
  ["toc", async () => (await import("@domternal/extension-toc")).TableOfContents],
  ["block_controls", async () => (await import("@domternal/extension-block-controls")).BlockControls],
  ["details", async () => (await import("@domternal/extension-details")).Details],
])

export function registerExtension(name, loader) {
  registry.set(name, loader)
}

export async function resolveExtensions(names, options = {}) {
  const resolved = await Promise.all(names.map(async (name) => {
    const loader = registry.get(name)
    if (!loader) {
      throw new Error(
        `[domternal] Unknown extension "${name}". Registered: ${Array.from(registry.keys()).join(", ")}. ` +
        "Register custom extensions with registerExtension() from \"domternal/extensions\"."
      )
    }
    return loader(options)
  }))
  return resolved.flat()
}
