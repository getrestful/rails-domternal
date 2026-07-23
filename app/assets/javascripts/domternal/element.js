import { resolveExtensions } from "domternal/extensions"
import { createUploadHandler } from "domternal/direct_upload"

// <domternal-editor input="..." data-extensions="starter_kit image" data-toolbar="full" ...>
//
// Mirrors <trix-editor>: a self-registering custom element that mounts the editor and
// keeps a linked hidden <input> in sync on every change, so it drops into a form exactly
// like ActionText's rich_textarea_tag output does.
export class DomternalEditorElement extends HTMLElement {
  static get observedAttributes() {
    return ["editable"]
  }

  connectedCallback() {
    if (this._mounted) return
    this._mounted = true
    this._mount()
  }

  disconnectedCallback() {
    this._toolbar?.destroy()
    this._wrapper?.destroy()
    this._mounted = false
  }

  attributeChangedCallback(name, _oldValue, newValue) {
    if (name === "editable" && this._wrapper) {
      this._wrapper.setEditable(newValue !== "false")
    }
  }

  get input() {
    const id = this.getAttribute("input")
    return id ? document.getElementById(id) : null
  }

  // The wrapper's current HTML, or "" before the editor has mounted.
  get value() {
    return this._wrapper?.htmlContent ?? ""
  }

  async _mount() {
    const input = this.input
    if (!input) {
      throw new Error(`[domternal] <domternal-editor> could not find its input (input="${this.getAttribute("input")}")`)
    }

    this.classList.add("dm-editor")
    this.innerHTML = `
      <div class="domternal-toolbar" part="toolbar"></div>
      <div class="domternal-surface" part="surface"></div>
    `
    const toolbarHost = this.querySelector(".domternal-toolbar")
    const surfaceHost = this.querySelector(".domternal-surface")

    const extensionNames = (this.dataset.extensions || "starter_kit image").split(/\s+/).filter(Boolean)
    const uploadHandler = createUploadHandler({
      directUploadUrl: this.dataset.directUploadUrl,
      blobUrlTemplate: this.dataset.blobUrlTemplate,
      onUploadError: (error, file) => this._dispatchUploadError(error, file)
    })

    const extensions = await resolveExtensions(extensionNames, {
      image: {
        uploadHandler,
        allowedMimeTypes: (this.dataset.allowedMimeTypes || "").split(/\s+/).filter(Boolean) || undefined,
        maxFileSize: this.dataset.maxFileSize ? Number(this.dataset.maxFileSize) : undefined
      }
    })

    const { DomternalEditor, DomternalToolbar } = await import("@domternal/vanilla")

    this._wrapper = new DomternalEditor(surfaceHost, {
      extensions,
      content: input.value,
      editable: this.getAttribute("editable") !== "false",
      onUpdate: ({ editor }) => this._syncInput(editor),
      onFocus: () => this._dispatch("domternal:focus"),
      onBlur: () => this._dispatch("domternal:blur")
    })

    if (this.dataset.toolbar && this.dataset.toolbar !== "false") {
      this._toolbar = new DomternalToolbar(toolbarHost, { editor: this._wrapper.editor })
    } else {
      toolbarHost.remove()
    }

    this._dispatch("domternal:initialize")
  }

  _syncInput(editor) {
    const input = this.input
    if (!input) return
    input.value = editor.getHTML()
    this._dispatch("domternal:change")
  }

  _dispatch(type, detail = {}) {
    this.dispatchEvent(new CustomEvent(type, { bubbles: true, detail: { element: this, ...detail } }))
  }

  _dispatchUploadError(error, file) {
    this._dispatch("domternal:upload-error", { error, file })
  }
}

if (!customElements.get("domternal-editor")) {
  customElements.define("domternal-editor", DomternalEditorElement)
}
