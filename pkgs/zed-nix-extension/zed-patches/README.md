# Embedded languages in Nix strings

`../zed.nix` builds the upstream `zed-extensions/nix` extension and
`nix-community/tree-sitter-nix` grammar at explicit revisions, with these local
patches applied. Refresh the source revisions and hashes there when updating.

The injection support comes from
[zed-extensions/nix#49](https://github.com/zed-extensions/nix/pull/49) and
[tree-sitter-nix#166](https://github.com/nix-community/tree-sitter-nix/pull/166).
The patches carry the comment scanner, grammar rules, queries and parser tests.
They do not carry the fork's flake task definitions.

Put a language-name comment directly before a string, for example:

```nix
programs.zsh.initContent = /* zsh */ ''
  autoload -Uz compinit
  compinit
'';
```

Line comments such as `# bash` work too. The named language must be available
in Zed. Zsh uses Zed's bundled shell grammar, with its existing syntax limits.
Nix interpolation remains outside the embedded language captures. This adds
syntax highlighting; embedded language-server features still need Zed support.

The grammar build regenerates the parser with Tree-sitter ABI 15 instead of
keeping generated C in the patch. Its check phase runs the parser corpus,
including the injection tests. When refreshing a pin, verify that the patches
apply, the corpus passes, and the packaged extension queries compile against
the regenerated grammar.

Home Manager installs only the patched Nix extension as a directory symlink.
Zed treats that as a development extension and excludes it from automatic
updates. The explicit `auto_install_extensions.nix` and
`auto_update_extensions.nix` settings also prevent registry replacement.
