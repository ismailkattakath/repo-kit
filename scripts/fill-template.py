"""Fill the template flake's required fields: fill-template.py FLAKE NAME YEAR HOLDER DESCRIPTION.

The header of template/flake.nix lists them. Each `throw` there fails evaluation by name
when left unfilled; the description is a plain placeholder string.
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

# The README stub beside the flake (template/README.md): its title and summary line.
readme = flake.with_name("README.md")
if readme.exists():
    body = readme.read_text()
    for token, value in (("@NAME@", name), ("@DESCRIPTION@", description)):
        if body.count(token) != 1:
            sys.exit(f"error: {token} occurs {body.count(token)} times in {readme}")
        body = body.replace(token, value)
    readme.write_text(body)
print(f"filled {path}: {name} ({year}, {holder})")
