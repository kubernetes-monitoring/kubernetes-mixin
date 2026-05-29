#!/usr/bin/env python3

# Copyright kubernetes-mixin Authors
# SPDX-License-Identifier: Apache-2.0
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

"""Prune contributors who have signed the CNCF CLA from the NOTICE file.

The NOTICE file lists contributors who could not be reached to sign the CNCF
CLA. Once a contributor signs (passes) the CLA they no longer need to be listed.
This script reads an EasyCLA status report -- a GitHub gist containing a
markdown table -- and removes every "Submitted on behalf of a third-party" line
from the NOTICE file whose contributor is marked "CLA Passed = Yes".

The gist is identified by a URL passed on the command line, so the report data
is never hard-coded into this repository. A local file path may also be passed
instead of a URL (useful for testing).

The gist is expected to contain a markdown table with (at least) these columns:

    | GitHub Username | Name | Email | CLA Passed | GitHub Account Linked |

Matching against NOTICE lines:
  * Lines of the form "... @<handle> (<name>)" are matched by GitHub handle
    (case-insensitively, as GitHub handles are case-insensitive).
  * Lines of the form "... <name> (GitHub handle unknown)" are matched by name
    against report rows that have no linked GitHub account ("(none)").

Usage:
    scripts/prune-cla-passed.py <gist-url-or-file> [--notice PATH] [--dry-run]
"""

import argparse
import os
import re
import sys
import urllib.request
from urllib.parse import urlparse, urlunparse

NOTICE_LINE_RE = re.compile(r"^Submitted on behalf of a third-party: (.+)$")
HANDLE_RE = re.compile(r"^@(\S+) \(.*\)$")
UNKNOWN_RE = re.compile(r"^(.*) \(GitHub handle unknown\)$")

# Values in the "CLA Passed" column that count as having passed/signed the CLA.
PASSED_VALUES = {"yes", "y", "true", "signed", "passed"}
# Placeholder used in the report when no GitHub account is linked.
NO_HANDLE = "(none)"


def to_raw_url(url):
    """Normalise a gist URL to its raw content URL.

    A standard gist page URL (https://gist.github.com/user/id) is rewritten to
    the raw host (https://gist.githubusercontent.com/user/id/raw). URLs that
    already point at raw content, or any non-gist URL, are returned unchanged.
    """
    parsed = urlparse(url)
    if parsed.netloc == "gist.github.com":
        path = parsed.path.rstrip("/")
        if not path.endswith("/raw"):
            path += "/raw"
        return urlunparse(("https", "gist.githubusercontent.com", path, "", "", ""))
    return url


def load_report(source):
    """Return the report text from a local file path or a (gist) URL."""
    if os.path.isfile(source):
        with open(source, encoding="utf-8") as handle:
            return handle.read()

    raw_url = to_raw_url(source)
    request = urllib.request.Request(raw_url, headers={"User-Agent": "prune-cla-passed"})
    with urllib.request.urlopen(request) as response:  # noqa: S310 (trusted gist URL)
        return response.read().decode("utf-8")


def _split_row(line):
    """Split a markdown table row into stripped cells."""
    cells = [cell.strip() for cell in line.strip().strip("|").split("|")]
    return cells


def parse_passed(report_text):
    """Parse the markdown table and return CLA-passed handles and anon names.

    Returns a tuple (passed_handles, passed_anon_names) where:
      * passed_handles is a set of lower-cased GitHub handles that passed, and
      * passed_anon_names is a set of names that passed but have no linked
        GitHub account (matched against "(GitHub handle unknown)" entries).
    """
    columns = None
    passed_handles = set()
    passed_anon_names = set()

    for line in report_text.splitlines():
        if "|" not in line:
            continue
        cells = _split_row(line)

        # Skip the markdown separator row (e.g. |---|---|).
        if cells and all(set(cell) <= {"-", ":"} and cell for cell in cells):
            continue

        lowered = [cell.lower() for cell in cells]
        if columns is None:
            # The header row is the one that names the columns we need.
            if "cla passed" in lowered and "github username" in lowered:
                columns = {name: idx for idx, name in enumerate(lowered)}
            continue

        idx_user = columns["github username"]
        idx_passed = columns["cla passed"]
        idx_name = columns.get("name")
        if max(idx_user, idx_passed) >= len(cells):
            continue

        if cells[idx_passed].lower() not in PASSED_VALUES:
            continue

        username = cells[idx_user]
        name = cells[idx_name] if idx_name is not None and idx_name < len(cells) else ""

        if username and username != NO_HANDLE:
            passed_handles.add(username.lower())
        elif name:
            passed_anon_names.add(name)

    if columns is None:
        raise ValueError(
            "Could not find a markdown table with 'GitHub Username' and "
            "'CLA Passed' columns in the report."
        )

    return passed_handles, passed_anon_names


def should_remove(line, passed_handles, passed_anon_names):
    """Return the matched contributor if this NOTICE line should be removed."""
    match = NOTICE_LINE_RE.match(line)
    if not match:
        return None
    payload = match.group(1)

    handle_match = HANDLE_RE.match(payload)
    if handle_match:
        handle = handle_match.group(1)
        if handle.lower() in passed_handles:
            return f"@{handle}"
        return None

    unknown_match = UNKNOWN_RE.match(payload)
    if unknown_match:
        name = unknown_match.group(1)
        if name in passed_anon_names:
            return name

    return None


def main():
    parser = argparse.ArgumentParser(
        description="Remove CLA-passed contributors from the NOTICE file using "
        "an EasyCLA status gist."
    )
    parser.add_argument(
        "gist",
        help="URL of the EasyCLA status gist (or a local file path to the report).",
    )
    default_notice = os.path.join(
        os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "NOTICE"
    )
    parser.add_argument(
        "--notice",
        default=default_notice,
        help="Path to the NOTICE file (default: repository NOTICE file).",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Report what would be removed without modifying the NOTICE file.",
    )
    args = parser.parse_args()

    try:
        report_text = load_report(args.gist)
    except Exception as err:  # noqa: BLE001 - surface a friendly message
        print(f"Error: failed to read report from {args.gist!r}: {err}", file=sys.stderr)
        return 1

    try:
        passed_handles, passed_anon_names = parse_passed(report_text)
    except ValueError as err:
        print(f"Error: {err}", file=sys.stderr)
        return 1

    print(
        f"Report lists {len(passed_handles)} CLA-passed GitHub handles "
        f"and {len(passed_anon_names)} CLA-passed unlinked contributors.",
        file=sys.stderr,
    )

    with open(args.notice, encoding="utf-8") as handle:
        lines = handle.readlines()

    kept = []
    removed = []
    for line in lines:
        matched = should_remove(line.rstrip("\n"), passed_handles, passed_anon_names)
        if matched is not None:
            removed.append(matched)
        else:
            kept.append(line)

    if not removed:
        print("No NOTICE entries matched a CLA-passed contributor. Nothing to do.")
        return 0

    print(f"Removing {len(removed)} entries from {args.notice}:", file=sys.stderr)
    for entry in removed:
        print(f"  - {entry}", file=sys.stderr)

    if args.dry_run:
        print("Dry run: NOTICE file left unchanged.", file=sys.stderr)
        return 0

    with open(args.notice, "w", encoding="utf-8") as handle:
        handle.writelines(kept)

    print(f"✓ Removed {len(removed)} entries from the NOTICE file.", file=sys.stderr)
    return 0


if __name__ == "__main__":
    sys.exit(main())
