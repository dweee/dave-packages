# REA with Kuna backends

`rea-kuna` supplies the `rea` executable with a source-built Kuna CLI, a separate
Ghidra installation using the Kuna core, and a full JDK. The plain `rea` package
is also available for callers managing their own engines.

```sh
nix shell github:dweee/dave-packages#kuna github:dweee/dave-packages#rea-kuna
rea doctor --provider ghidra --json
rea decompile /path/to/binary function_name
REA_ANALYSIS_PROVIDER=kuna rea decompile /path/to/binary function_name
```

Ghidra is the default provider and supplies the broader native inspection
surface. The optional `kuna` provider invokes the CLI directly. Both paths were
verified with Kuna 1.910. Mach-O symbols may retain a leading underscore.

Explicit `GHIDRA_INSTALL_DIR`, `JAVA_HOME`, `REA_KUNA_COMMAND` and
`REA_ANALYSIS_PROVIDER` settings override the defaults. The launcher aligns
`NIX_GHIDRAHOME` with the selected Ghidra directory so an inherited stock module
root cannot silently select another backend. REA 6.7 expects Ghidra 12.1.x;
the catalog lock currently supplies 12.1.4 and JDK 21.

Register the launcher's absolute `bin/rea` executable with `args: ["mcp"]` in a
client's stdio MCP configuration. For package updates, point the client at a
stable executable link managed by the user's configuration. Keep unrelated
servers and private client settings intact. T3 Code providers can use their
underlying coding client's configuration; reconnect existing sessions after
changing MCP registrations.

The complete skills are supplied by `kuna/share/kuna/skills/kuna-decompiler`
and `rea/share/rea/skills/reverse-engineer-anything`. Link or copy these complete
directories into the client's documented skill search path. Kuna itself has
no MCP server. Installing a skill alone does not register REA or install engines.
This catalog does not mutate client configurations or run upstream setup.

See [REA limitations](../rea/README.md) for optional engines, excluded Frida,
and upstream installer-ownership diagnostics for Nix-managed paths. Install
`kuna` and `rea-kuna` for agent use; `ghidra-kuna` need not be added to the user
profile separately.
