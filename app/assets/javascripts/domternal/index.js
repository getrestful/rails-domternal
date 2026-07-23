// Entry point for `import "domternal"`. The install generator pins this whole directory
// (`pin_all_from ..., under: "domternal"`), so sibling files import each other by bare
// specifier (e.g. "domternal/extensions") rather than by relative path — Propshaft/Sprockets
// fingerprint each file independently, and a relative "./extensions.js" import would resolve
// against the browser's literal (un-fingerprinted) URL and 404.
export { DomternalEditorElement } from "domternal/element"
export { registerExtension } from "domternal/extensions"
