# Tuwunel authenticated media redirects

This package patches the locked nixpkgs `matrix-tuwunel` to support HTTP 307
redirects for authenticated media downloads and thumbnails. With
`media_allow_redirect = true`, eligible S3 objects use five-minute signed URLs.
Authentication still runs before storage access; responses containing signed
URLs use `Cache-Control: private, no-store`.

New media writes preserve sanitized Content-Type and Content-Disposition,
including multipart uploads and generated thumbnails. A HEAD request checks
object existence and headers before redirecting. Uploads, cold federation
fetches and server-to-server federation endpoints retain their existing paths.

Local-only media, unavailable objects, old objects without expected headers,
alternate filename requests and strict media policies use the normal proxy.
The patch does not migrate existing storage.

## Build and configure

```sh
nix build .#matrix-tuwunel
```

The package retains nixpkgs' Rust tests and adds a disposable loopback S3 fixture
with synthetic credentials. The fixture checks authentication, signed URLs,
headers, route aliases, thumbnails, multipart writes and fallback behavior.
The exported package depends on that validation.

Configure the existing Matrix service to use this package. Supply S3 credentials
through its runtime secret mechanism, with a private bucket and the correct
regional endpoint. Enable redirects only after the patched runtime is active.

Browser clients also need bucket CORS. `b2-cors.json` is an S3 `PutBucketCors`
template permitting GET, HEAD and range requests. Its wildcard origin supports
cross-origin redirects that send `Origin: null`; CORS does not grant object
access, and signed URLs remain required. Review the template before applying it.
See [Backblaze's CORS documentation](https://www.backblaze.com/docs/cloud-storage-cross-origin-resource-sharing-rules).

Verify authenticated uploads, redirects and subsequent storage requests in the
client's browser. The protocol fixture does not establish compatibility with
every browser, object store or deployment.
