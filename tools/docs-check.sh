#!/usr/bin/env bash
# The docs' links resolve (files and headings, as GitHub slugs them), and every Lua block in a guide, the README
# and getting-started is lifted as it is from a file that runs: the example mod's file the guide links, the
# parasite repo's archived registry (the model) when that checkout is beside this one, the scaffold's init.lua
# (with HORIZON).
#
#   [HORIZON=/path/to/horizon] tools/docs-check.sh
set -u
HERE=$(cd "$(dirname "$0")/.." && pwd)
python3 - "$HERE" "${HORIZON:-}" <<'PY'
import re, sys, os, glob
root, horizon = sys.argv[1], sys.argv[2]
failed = 0
def slug(h):
    h = re.sub(r'`', '', h.strip().lower())
    h = re.sub(r'[^\w\- ]', '', h)
    return h.replace(' ', '-')
def anchors(path):
    out = set()
    for line in open(path, encoding='utf-8'):
        m = re.match(r'(#{1,6})\s+(.*)', line)
        if m: out.add(slug(m.group(2)))
    return out
docs = [os.path.join(root, 'README.md')] + sorted(glob.glob(os.path.join(root, 'docs', '**', '*.md'), recursive=True)) \
     + [os.path.join(root, 'examples', 'example_mod', 'README.md')]
for doc in docs:
    text = open(doc, encoding='utf-8').read()
    rel = os.path.relpath(doc, root)
    for m in re.finditer(r'\]\(([^)\s]+)\)', text):
        link = m.group(1)
        if link.startswith(('http://', 'https://', 'mailto:')): continue
        target, _, anchor = link.partition('#')
        path = os.path.normpath(os.path.join(os.path.dirname(doc), target)) if target else doc
        if not os.path.exists(path):
            print(f"BROKEN {rel}: {link} (no {os.path.relpath(path, root)})"); failed = 1; continue
        if anchor and path.endswith('.md') and anchor not in anchors(path):
            print(f"BROKEN {rel}: {link} (no heading #{anchor} in {os.path.relpath(path, root)})"); failed = 1
    # Every ```lua block of a guide, the README and getting-started comes from a file that runs (api.md is the
    # reference: its blocks illustrate).
    if not (rel.startswith('docs/guides/') or rel in ('README.md', 'docs/getting-started.md')): continue
    blocks = re.findall(r'```lua\n(.*?)```', text, re.S)
    if not blocks: continue
    sources = []
    for m in re.finditer(r'\]\(([^)\s#]+)', text):
        link = m.group(1)
        if 'examples/example_mod' in link and link.endswith('.lua'):
            sources.append(os.path.normpath(os.path.join(os.path.dirname(doc), link)))
        if 'horizon-parasite-mod' in link and link.endswith('registry.lua'):
            # The example that moved here left its registry (the model) at that repo's example-archive tag.
            repo = os.path.join(root, '..', 'horizon-parasite-mod')
            if os.path.isdir(os.path.join(repo, '.git')):
                import subprocess
                r = subprocess.run(['git', '-C', repo, 'show', 'example-archive:scripts/registry.lua'], capture_output=True, text=True)
                if r.returncode == 0: sources.append(('archive', r.stdout))
    if rel in ('README.md', 'docs/getting-started.md') and horizon:
        p = os.path.join(horizon, 'crates', 'cargo-horizon-mod', 'template', 'lua', 'init.lua')
        if os.path.exists(p): sources.append(('template', p))
    for block in blocks:
        found = False
        for src in sources:
            if isinstance(src, tuple) and src[0] == 'archive':
                code = src[1]
            elif isinstance(src, tuple):
                code = open(src[1], encoding='utf-8').read().replace('{id}', 'my_mod')
            else:
                code = open(src, encoding='utf-8').read()
            if block.strip() in code: found = True; break
        if not found:
            if not sources:
                print(f"UNCHECKED {rel}: a Lua block with no example file linked" + ("" if horizon else " (set HORIZON for the scaffold's)"))
            else:
                names = [s[0] if isinstance(s, tuple) and s[0] == 'archive' else os.path.relpath(s[1] if isinstance(s, tuple) else s, root) for s in sources]
                print(f"NOT LIFTED {rel}: a Lua block is not in {', '.join(names)}:\n  " + block.strip().splitlines()[0]); failed = 1
print("docs-check:", "FAILED" if failed else "ok, every link resolves and every Lua block is lifted from a file that runs")
sys.exit(failed)
PY
