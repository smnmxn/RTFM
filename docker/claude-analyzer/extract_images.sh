#!/bin/bash
set -e

# extract_images.sh — Extract brand/UI images from a repository as base64 data URIs
#
# Walks the repo for image files, skipping node_modules/.git/vendor/etc.
# Prioritises brand images (logo, icon, favicon, hero, etc.).
# No Claude calls — pure filesystem walk.
#
# Required environment variables:
# - GITHUB_REPO: owner/repo format
# - GITHUB_TOKEN: GitHub access token
#
# Output:
# - /output/images_base64.json — Image data URIs keyed by multiple path patterns
# - /output/images_manifest.txt — List of available image keys (for Claude prompts)

echo "Starting image extraction..."
echo "Repository: ${GITHUB_REPO}"

# ─── Clone ───────────────────────────────────────────────────────────────────

if [ ! -d /repo/.git ]; then
    echo "Cloning repository..."
    if ! git clone --depth 1 "https://x-access-token:${GITHUB_TOKEN}@github.com/${GITHUB_REPO}.git" /repo 2>&1; then
        echo "ERROR: Failed to clone repository ${GITHUB_REPO}"
        exit 1
    fi
fi

# ─── Extract ─────────────────────────────────────────────────────────────────

echo "Scanning for images..."

python3 - /repo /output/images_base64.json <<'PYEOF'
import os, sys, base64, json

repo_dir = sys.argv[1]
output_file = sys.argv[2]

MAX_FILE_SIZE = 50 * 1024      # 50KB per image
MAX_TOTAL_SIZE = 500 * 1024    # 500KB total base64 budget
IMAGE_EXTENSIONS = {'.png', '.jpg', '.jpeg', '.gif', '.svg', '.webp', '.ico'}
SKIP_DIRS = {'node_modules', '.git', 'vendor', 'tmp', 'log', 'coverage',
             '.bundle', 'dist', 'build', '.next', '.nuxt', '__pycache__',
             '.cache', '.parcel-cache', 'bower_components'}
PRIORITY_NAMES = {'logo', 'brand', 'favicon', 'icon', 'avatar', 'placeholder', 'default', 'hero'}

mime_map = {
    '.png': 'image/png', '.jpg': 'image/jpeg', '.jpeg': 'image/jpeg',
    '.gif': 'image/gif', '.svg': 'image/svg+xml', '.webp': 'image/webp',
    '.ico': 'image/x-icon',
}

found = []

for root, dirs, files in os.walk(repo_dir):
    dirs[:] = [d for d in dirs if d not in SKIP_DIRS]
    for fname in files:
        ext = os.path.splitext(fname)[1].lower()
        if ext not in IMAGE_EXTENSIONS:
            continue
        fpath = os.path.join(root, fname)
        try:
            fsize = os.path.getsize(fpath)
        except OSError:
            continue
        if fsize > MAX_FILE_SIZE or fsize == 0:
            continue
        rel_path = os.path.relpath(fpath, repo_dir)
        # Skip fingerprinted/hashed copies (e.g. logo-abc123def456.png)
        name_no_ext = os.path.splitext(fname)[0]
        if len(name_no_ext) > 40 and '-' in name_no_ext:
            parts = name_no_ext.rsplit('-', 1)
            if len(parts[1]) > 20:
                continue
        name_lower = name_no_ext.lower()
        is_priority = any(p in name_lower for p in PRIORITY_NAMES)
        found.append({
            'rel_path': rel_path,
            'abs_path': fpath,
            'size': fsize,
            'ext': ext,
            'priority': is_priority,
        })

# Sort: priority files first, then by size (smaller first)
found.sort(key=lambda x: (not x['priority'], x['size']))

images = {}
unique_data_uris = set()
total_b64_size = 0

for item in found:
    try:
        with open(item['abs_path'], 'rb') as f:
            data = f.read()
        b64 = base64.b64encode(data).decode('ascii')
        b64_size = len(b64)
        if total_b64_size + b64_size > MAX_TOTAL_SIZE:
            continue
        mime = mime_map.get(item['ext'], 'application/octet-stream')
        data_uri = f"data:{mime};base64,{b64}"

        if data_uri in unique_data_uris:
            images[item['rel_path']] = data_uri
            continue
        unique_data_uris.add(data_uri)

        rel = item['rel_path']
        fname = os.path.basename(rel)

        # Map under multiple keys for flexible lookup
        images[rel] = data_uri
        images['/' + rel] = data_uri
        images[fname] = data_uri
        images['/' + fname] = data_uri
        for prefix in ['/assets/', '/images/', '/img/', '/static/']:
            images[prefix + fname] = data_uri

        total_b64_size += b64_size
        print(f"  {item['size']//1024:>3}KB  {rel}")
    except Exception:
        continue

count = len(unique_data_uris)
with open(output_file, 'w') as f:
    json.dump({"count": count, "total_b64_bytes": total_b64_size, "images": images}, f)

print(f"\n  Total: {count} unique image(s), {total_b64_size // 1024}KB base64")
PYEOF

# Build manifest (just keys, no data)
jq -r '.images | keys[]' /output/images_base64.json 2>/dev/null | sort -u > /output/images_manifest.txt

IMAGE_COUNT=$(jq -r '.count // 0' /output/images_base64.json 2>/dev/null || echo "0")
TOTAL_KB=$(jq -r '.total_b64_bytes // 0' /output/images_base64.json 2>/dev/null | python3 -c "import sys; print(int(sys.stdin.read()) // 1024)")

echo ""
echo "Image extraction complete!"
echo "  Images: ${IMAGE_COUNT}"
echo "  Size: ${TOTAL_KB}KB base64"
echo ""
echo "Output files:"
ls -la /output/images_base64.json /output/images_manifest.txt 2>/dev/null || true
