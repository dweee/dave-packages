#!/usr/bin/env python3
"""Patch UKBinCollectionData sources during the Nix build.

Fixes skip_get_url being dropped (store_true CLI flag) and coordinator
timeouts wiping last-good bin data.
"""

from pathlib import Path

INIT = Path("custom_components/uk_bin_collection/__init__.py")
CONST = Path("custom_components/uk_bin_collection/const.py")
TEST = Path("custom_components/uk_bin_collection/tests/test_init.py")

OLD_FMT = """    def _format_web_driver(v):
        return [f"--web_driver={v.rstrip('/')}"] if v is not None else []

    formatters = {
        "headless": _format_headless,
        "web_driver": _format_web_driver,
    }
"""

NEW_FMT = """    def _format_web_driver(v):
        return [f"--web_driver={v.rstrip('/')}"] if v is not None else []

    def _format_skip_get_url(v):
        if v is True or str(v).lower() in ("true", "1", "yes"):
            return ["--skip_get_url"]
        return []

    formatters = {
        "headless": _format_headless,
        "web_driver": _format_web_driver,
        "skip_get_url": _format_skip_get_url,
    }
"""

OLD_TO = """        except asyncio.TimeoutError as exc:
            _LOGGER.error(f"{LOG_PREFIX} Timeout while updating data: {exc}")
            raise UpdateFailed(f"Timeout while updating data: {exc}") from exc
"""

NEW_TO = """        except asyncio.TimeoutError as exc:
            _LOGGER.error(f"{LOG_PREFIX} Timeout while updating data: {exc}")
            if self._last_good_data:
                _LOGGER.warning(
                    f"{LOG_PREFIX} Using last known good data after timeout."
                )
                return self._last_good_data
            raise UpdateFailed(f"Timeout while updating data: {exc}") from exc
"""

OLD_TEST = '''def test_build_ukbcd_args_excludes_keys():
    config_data = {
        "council": "Test Council",
        "url": "http://example.com",
        "skip_get_url": "should be excluded",
        "custom_arg": "value",
    }
    args = build_ukbcd_args(config_data)
    # Check that the first two arguments are the council and url.
    assert args[0] == "Test Council"
    assert args[1] == "http://example.com"
    # The custom_arg should be included, but skip_get_url should not.
    args_str = " ".join(args)
    assert "--custom_arg=value" in args_str
    assert "skip_get_url" not in args_str
'''

NEW_TEST = '''def test_build_ukbcd_args_excludes_keys():
    config_data = {
        "council": "Test Council",
        "url": "http://example.com",
        "timeout": "should be excluded",
        "custom_arg": "value",
    }
    args = build_ukbcd_args(config_data)
    # Check that the first two arguments are the council and url.
    assert args[0] == "Test Council"
    assert args[1] == "http://example.com"
    args_str = " ".join(args)
    assert "--custom_arg=value" in args_str
    assert "timeout" not in args_str


def test_build_ukbcd_args_emits_skip_get_url_flag():
    config_data = {
        "council": "NorthNorthamptonshireCouncil",
        "url": "https://example.invalid/",
        "skip_get_url": True,
        "uprn": "100031021318",
    }
    args = build_ukbcd_args(config_data)
    assert "--skip_get_url" in args
    assert not any(a.startswith("--skip_get_url=") for a in args)


def test_build_ukbcd_args_omits_skip_get_url_when_false():
    config_data = {
        "council": "NorthNorthamptonshireCouncil",
        "url": "https://example.invalid/",
        "skip_get_url": False,
    }
    args = build_ukbcd_args(config_data)
    assert "--skip_get_url" not in args
'''


def _replace(path: Path, old: str, new: str, label: str) -> None:
    text = path.read_text()
    if old not in text:
        raise SystemExit(f"{label} not found in {path}")
    path.write_text(text.replace(old, new, 1))


def main() -> None:
    const = CONST.read_text()
    const_old = '    "skip_get_url",\n'
    if const_old not in const:
        raise SystemExit("skip_get_url exclusion not found in const.py")
    CONST.write_text(const.replace(const_old, "", 1))
    _replace(INIT, OLD_FMT, NEW_FMT, "formatter block")
    _replace(INIT, OLD_TO, NEW_TO, "timeout handler")
    _replace(TEST, OLD_TEST, NEW_TEST, "build_ukbcd_args test")


if __name__ == "__main__":
    main()
