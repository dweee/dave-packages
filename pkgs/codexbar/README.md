# CodexBar CLI and Plasma widget

`codexbar-plasmoid` applies `patches/summary-pace-markers.patch` to the pinned
fork. The provider tabs and both overview bars use the same expected-usage
markers and pace colors as the detailed provider cards. They follow **Show
pace**, **Work days**, and the used/remaining display setting. Tabs use the
window behind their percentage, including the weekly fallback. Missing,
unknown, synthetic, exhausted, or ineligible windows have no pace marker.

Build and run the packaged JavaScript checks with:

```sh
nix build .#codexbar-plasmoid
```

## z.ai / GLM

For a personal Global Coding Plan, save the key using CodexBar CLI 0.84.0:

```sh
printf '%s' "$Z_AI_API_KEY" | codexbar config set-api-key --provider zai --stdin
codexbar config validate
codexbar usage --provider zai
```

This assumes `Z_AI_API_KEY` is already set in that terminal. The command saves
the key in the shared CodexBar config, so Plasma does not need to inherit the
terminal environment. Enable **z.ai / GLM** in the widget's **Providers**
settings and leave its source as **Auto**.

Alternatively, set **General → CLI environment file** to a private file such
as `~/.config/codexbar/widget.env` containing `Z_AI_API_KEY='your-api-key'`,
and set its permissions with `chmod 600 ~/.config/codexbar/widget.env`.
This file is read only for the widget's CLI subprocesses. Exporting the key
in a terminal alone does not make it available to an already running Plasma.

For BigModel China, select `bigmodel-cn` in the z.ai provider's shared config
(`region` field); team plans also require organization and project IDs.
These are Coding Plan quota APIs: a Global pay-as-you-go key alone does not
establish a subscription quota. See the [versioned z.ai documentation](https://github.com/steipete/CodexBar/blob/v0.84.0/docs/zai.md)
for region, team, and balance-only support. The macOS settings UI described
there is separate from the Plasma widget's settings.

## Antigravity

Enable **Antigravity** in the widget's **Providers** settings, with source
**Auto**. Sign in to the Antigravity app and leave it running, then test:

```sh
codexbar usage --provider antigravity
```

For operation without the desktop app, install Google's `agy` CLI and run
`agy` interactively once to sign in. CodexBar can use its local server or
its noninteractive usage report. If Plasma cannot find the executable, put
`ANTIGRAVITY_CLI_PATH='/absolute/path/to/agy'` in the widget's CLI environment
file. Refresh the widget after testing the CLI. This uses the Antigravity
Google login, rather than a Gemini API key.

The older IDE language-server source may provide only session/model quotas;
weekly quotas require a source that supplies the grouped quota summary.
CodexBar also supports saved Google OAuth credentials, but the plasmoid
does not provide the macOS app's account-login UI. See the [versioned
Antigravity documentation](https://github.com/steipete/CodexBar/blob/v0.84.0/docs/antigravity.md)
for OAuth and CLI-version fallback details.
