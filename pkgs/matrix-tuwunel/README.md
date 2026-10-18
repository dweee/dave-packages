# Tuwunel authenticated media redirects

Local patch over the flake's locked nixpkgs `matrix-tuwunel` (currently 1.9.3).
No fork or Ruma change is required. Keep the existing NixOS module; the shared
Linux overlay selects this package for Terra and exports the same derivation as
`packages.x86_64-linux.matrix-tuwunel`.

With `media_allow_redirect = true`, authenticated download and thumbnail requests
can return HTTP 307 to an existing object on an S3 provider. The existing signer
issues five-minute URLs. The response containing the URL has `Cache-Control:
private, no-store`. Matrix access-token authentication still runs through the
Ruma request extractor before any storage request or signing. Stable and unstable
route aliases come from Ruma's existing route history.

New media writes retain Matrix's sanitized Content-Type and Content-Disposition
on S3, including multipart uploads and generated thumbnails. A HEAD request checks
object existence and headers before redirecting; the Matrix server does not fetch
the body on that path. Private buckets stay private. Uploads still pass through
Matrix. Cached remote media is eligible too; a cold federation fetch and the
server-to-server federation endpoints retain their existing transfer paths.

The normal proxy path handles local-only media, older objects lacking the expected
headers, missing/unavailable S3 objects, alternate filename requests whose header
differs from the stored filename, and strict media framing/style policies. Nothing
rewrites old objects or migrates existing local media. Thumbnails are generated on
Matrix as before; subsequent eligible requests go directly to S3.

## Build and CI

```sh
nix build .#matrix-tuwunel
```

The compiled package retains nixpkgs' Rust unit tests. A separate validation
derivation boots a disposable server against a loopback S3 fixture, using synthetic credentials.
It verifies auth rejection, direct body delivery, SigV4 signatures and expiry,
filename/type headers, unsafe-content attachment policy, stable/unstable routes,
thumbnails, multipart writes, local/old-object fallback, and disabled/strict modes.
It never accesses the production database or Backblaze. The exported package is
only realized after this validation passes; test changes reuse the Rust build.

The existing `pr-host-checks` builds Terra's closure, and `nix-cache` builds and
caches that closure on main. Both therefore build this patched package and run its
validation, without another workflow or cache credential. They first build
Terra's configured Matrix package with a 150-minute cold-build budget;
the ordinary host's 15-minute per-derivation limit and cached-kernel prerequisite
stay in place. The main workflow's existing hook caches the completed package.
The workflows consume committed refs; an uncommitted checkout cannot be
dispatched to Actions.
Do not publish a commit just to run the workflow when the owner has forbidden it.

## Backblaze setup

Terra enables S3 and redirects only when its existing encrypted `tuwunelS3Env.age`
is present. The runtime must actually use the patched package before enabling it.
Supply the bucket-scoped S3 credentials through that secret, retaining a private
bucket and the correct regional endpoint.

Browser clients also need bucket CORS. `b2-cors.json` is an S3 `PutBucketCors` / AWS
CLI configuration allowing GET/HEAD and range requests. It uses `AllowedOrigins:
["*"]` because a browser requesting Matrix from a different client origin sends
`Origin: null` after the subsequent redirect to storage. A Chromium transport
test confirmed this and confirmed that the Matrix bearer header is stripped.
Restricting CORS to the Cinny/Sable domains would break that redirect. Applying
the template is an explicit bucket operation; this package does not change B2.
CORS grants no object access: the bucket stays private and the signed URL remains
necessary. See [Backblaze's CORS documentation](https://www.backblaze.com/docs/cloud-storage-cross-origin-resource-sharing-rules).

After the credentials, CORS and package are active, verify a real upload from
Cinny/Sable, a 307 on its authenticated media request, and a subsequent GET to B2
in the browser network inspector. The protocol fixture does not prove browser
compatibility or live Backblaze configuration. Do not switch Terra as part of a
package-only build.
