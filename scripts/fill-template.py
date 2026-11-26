"""Fill the template flake's four required fields: fill-template.py FLAKE NAME YEAR HOLDER DESCRIPTION.

Each field is a `throw` in template/flake.nix, so an unfilled one fails evaluation by name.
Every substitution must match exactly once, or this exits non-zero without writing.
"""

import json
import pathlib
import re
import sys

path, name, year, holder, description = sys.argv[1:6]
if not re.fullmatch(r"[a-z0-9][a-z0-9._-]*", name):
    sys.exit(f"error: name {name!r} is not kebab-case")
if not re.fullmatch(r"\d{4}", year):
    sys.exit(f"error: year {year!r} is not a four-digit year")

flake = pathlib.Path(path)
text = flake.read_text()
def nix_str(value: str) -> str:
    """A Nix string literal: JSON's escapes for \\" and \\\\ match Nix's; `${` must not interpolate."""
    return json.dumps(value).replace("${", "\\${")


subs = [
    (r'name = throw "[^"]*";', f"name = {nix_str(name)};"),
    (r'year = throw "[^"]*";', f"year = {nix_str(year)};"),
    (r'holder = throw "[^"]*";', f"holder = {nix_str(holder)};"),
    (r'description = "One line: what this repository is";', f"description = {nix_str(description)};"),
]
for pattern, replacement in subs:
    text, n = re.subn(pattern, lambda _m, r=replacement: r, text)
    if n != 1:
        sys.exit(f"error: {pattern!r} matched {n} times in {path}")
flake.write_text(text)
print(f"filled {path}: {name} ({year}, {holder})")
