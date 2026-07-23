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
  ["math", async () => {
    const { MathBlock, MathInline, MathEditing } = await import("@domternal/extension-math")
    return [MathBlock, MathInline, MathEditing]
  }],
  ["code_block", async () => (await import("@domternal/extension-code-block-lowlight")).CodeBlockLowlight],
  ["toc", async () => {
    const { UniqueID } = await import("@domternal/core")
    const { TableOfContents, TableOfContentsBlock } = await import("@domternal/extension-toc")
    return [UniqueID, TableOfContents, TableOfContentsBlock]
  }],
  // The Notion-style block UX (drag handle, block context menu, slash command, smart
  // paste, keyboard reorder) ships as five separate extensions rather than one bundle.
  ["block_controls", async () => {
    const { BlockHandle, BlockContextMenu, KeyboardReorder, SlashCommand, SmartPaste, FloatingMenu } =
      await import("@domternal/extension-block-controls")
    return [BlockHandle, BlockContextMenu, KeyboardReorder, SlashCommand, SmartPaste, FloatingMenu]
  }],
  ["details", async () => {
    const { Details, DetailsSummary, DetailsContent } = await import("@domternal/extension-details")
    return [Details, DetailsSummary, DetailsContent]
  }],
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
