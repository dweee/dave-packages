"""Start an MCP stdio server and require a handshake plus named tools.

Usage: mcp-stdio-smoke.py --tool NAME [--tool NAME ...] -- COMMAND [ARGS...]

Wrapper packages only shellcheck at build time, so a server whose Python
imports fail (for example `mcp.server.fastmcp` under mcp 2.x) still builds.
This check runs the real entry point through the SDK client instead.
"""

import argparse
import sys

import anyio
from mcp import ClientSession, StdioServerParameters
from mcp.client.stdio import stdio_client


async def run(tools: list[str], command: list[str]) -> None:
    params = StdioServerParameters(command=command[0], args=command[1:])
    with anyio.fail_after(60):
        async with stdio_client(params) as (read, write):
            async with ClientSession(read, write) as session:
                init = await session.initialize()
                listed = {tool.name for tool in (await session.list_tools()).tools}
    missing = sorted(set(tools) - listed)
    print(f"{init.server_info.name}: {len(listed)} tools advertised")
    if missing:
        sys.exit(f"missing tools: {', '.join(missing)}; advertised: {sorted(listed)}")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--tool", action="append", default=[], dest="tools")
    parser.add_argument("command", nargs=argparse.REMAINDER)
    args = parser.parse_args()
    command = args.command[1:] if args.command[:1] == ["--"] else args.command
    if not command:
        parser.error("missing server command")
    anyio.run(run, args.tools, command)


if __name__ == "__main__":
    main()
