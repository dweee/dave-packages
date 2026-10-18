#!/usr/bin/env python3
from pathlib import Path
import re
import sys

src, dest = sys.argv[1], sys.argv[2]
text = Path(src).read_text()
replacement = """  - condition: template
    value_template: >
      {% set old = trigger.event.data.old_state %}
      {% set new = trigger.event.data.new_state %}
      {% if old is none or new is none %}
        false
      {% elif old.state in ['unavailable', 'unknown'] or new.state in ['unavailable', 'unknown'] %}
        false
      {% else %}
        {% set old_ts = old.attributes.get('last_reported', 'none') %}
        {% set new_ts = new.attributes.get('last_reported', 'new') %}
        {% set event_age = as_timestamp(now()) - as_timestamp(new.state, 0) %}
        {{ old_ts != new_ts and event_age >= 0 and event_age < 10 }}
      {% endif %}
"""
pattern = re.compile(
    r"  - condition: template\n"
    r"    value_template: >\n"
    r"      \{% if trigger\.event\.data\.new_state is none %\}\n"
    r".*?"
    r"      \{% endif %\}\n",
    re.S,
)
new_text, count = pattern.subn(replacement, text, count=1)
if count != 1:
    raise SystemExit(f"expected to patch 1 reconnect guard, patched {count}")
new_text = new_text.replace(
    'name: "IKEA BILRESA - Light Controller (v1.2)"',
    'name: "IKEA BILRESA - Light Controller (v1.2, reconnect-guard)"',
    1,
)
new_text = new_text.replace(
    'name: "IKEA BILRESA - Light Controller (v1.3)"',
    'name: "IKEA BILRESA - Light Controller (v1.3, reconnect-guard)"',
    1,
)
Path(dest).write_text(new_text)
