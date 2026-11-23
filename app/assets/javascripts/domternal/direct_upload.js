// Bridges the Domternal image extension's `uploadHandler` (a `(file) => Promise<string url>`
// callback) to Active Storage direct uploads, matching the convention ActionText's
// rich_textarea_tag uses for its `data-direct-upload-url` / `data-blob-url-template`.
import { DirectUpload } from "@rails/activestorage"

export function createUploadHandler({ directUploadUrl, blobUrlTemplate, onUploadStart, onUploadEnd, onUploadError }) {
  return function uploadHandler(file) {
    return new Promise((resolve, reject) => {
      const upload = new DirectUpload(file, directUploadUrl)
      onUploadStart?.(file)

      upload.create((error, blob) => {
        onUploadEnd?.(file)

        if (error) {
          onUploadError?.(error, file)
          reject(error)
          return
        }

        const url = blobUrlTemplate
          .replace(":signed_id", blob.signed_id)
          .replace(":filename", encodeURIComponent(blob.filename))

        resolve(url)
      })
    })
  }
}
