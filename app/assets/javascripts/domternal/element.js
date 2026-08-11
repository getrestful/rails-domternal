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

    // Editors that aren't on screen yet (locale tabs, accordions, anything display:none)
    // wait to mount. Each one pulls its own extension modules and builds a ProseMirror
    // instance, so a form with one editor per locale would otherwise pay for all of them
    // up front. Setting the `eager` attribute opts out.
    if (this.hasAttribute("eager") || !this._canDeferMount()) {
      this._startMount()
    } else {
      this._observeVisibility()
    }
  }

  disconnectedCallback() {
    this._visibilityObserver?.disconnect()
    this._visibilityObserver = null
    this._toolbar?.destroy()
    this._bubbleMenu?.destroy()
    this._floatingMenu?.destroy()
    this._notionColorPicker?.destroy()
    this._wrapper?.destroy()
    this._mounted = false
    this._mountPromise = null
  }

  // Mounts now if the element is already laid out, otherwise once it first becomes visible.
  _observeVisibility() {
    if (this._isVisible()) {
      this._startMount()
      return
    }

    this._visibilityObserver = new IntersectionObserver((entries) => {
      if (!entries.some((entry) => entry.isIntersecting)) return
      this._visibilityObserver?.disconnect()
      this._visibilityObserver = null
      this._startMount()
    })
    this._visibilityObserver.observe(this)
  }

  _canDeferMount() {
    return typeof IntersectionObserver !== "undefined"
  }

  _isVisible() {
    return this.offsetParent !== null || this.getClientRects().length > 0
  }

  _startMount() {
    if (!this._mountPromise) {
      this._mounted = true
      this._mountPromise = this._mount()
    }
    return this._mountPromise
  }

  // Resolves once the editor is mounted, mounting it immediately if it was still deferred.
  // Use before reading `value` or driving the editor from outside.
  async ready() {
    await this._startMount()
    return this
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

  // Public access to the mounted ProseMirror editor. Returns null while the editor is
  // deferred or mounting; call `await element.ready()` before using it when necessary.
  get editor() {
    return this._wrapper?.editor ?? null
  }

  // Public access to the fixed toolbar, when one is configured. Notion-style and
  // toolbar-less editors return null.
  get toolbar() {
    return this._toolbar ?? null
  }

  // The editor's current HTML. Falls back to the linked input while the editor is still
  // deferred or mounting — an unmounted editor never touches the input, so the value the
  // server rendered is still the right answer and submitting the form is always safe.
  get value() {
    return this._wrapper?.htmlContent ?? this.input?.value ?? ""
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

    const { DomternalEditor, DomternalToolbar, DomternalBubbleMenu, DomternalFloatingMenu, DomternalNotionColorPicker } =
      await import("@domternal/vanilla")

    this._wrapper = new DomternalEditor(surfaceHost, {
      extensions,
      content: input.value,
      editable: this.getAttribute("editable") !== "false",
      onUpdate: ({ editor }) => this._syncInput(editor),
      onFocus: () => this._dispatch("domternal:focus"),
      onBlur: () => this._dispatch("domternal:blur")
    })

    const toolbarMode = this.dataset.toolbar || "full"
    const editor = this._wrapper.editor

    if (toolbarMode === "notion") {
      // Notion-style: no fixed toolbar. A selection bubble menu handles inline formatting,
      // a "+" floating menu (triggered only via the block handle's button, not on every
      // empty paragraph) inserts blocks, and the block handle/slash command/drag-reorder
      // themselves come from the "block_controls" extensions — add that to `extensions:`
      // on has_rich_domternal for this to have anything to control.
      toolbarHost.remove()

      const bubbleHost = document.createElement("div")
      bubbleHost.className = "dm-bubble-menu"
      this.appendChild(bubbleHost)
      this._bubbleMenu = new DomternalBubbleMenu(bubbleHost, { editor })

      const floatingHost = document.createElement("div")
      floatingHost.className = "dm-floating-menu"
      this.appendChild(floatingHost)
      this._floatingMenu = new DomternalFloatingMenu(floatingHost, { editor, requireExplicitTrigger: true })

      this._notionColorPicker = new DomternalNotionColorPicker({ editor })
    } else if (toolbarMode !== "false") {
      this._toolbar = new DomternalToolbar(toolbarHost, { editor })
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
