#!/bin/sh
# update-repo.sh
# Run in CI/workflow only (not during local tests)

set -u

handle_error() {
  echo "Error: $1" >&2
  exit 1
}

REPO="NovaDev404/NexStore"
API_URL="https://api.github.com/repos/$REPO/releases/latest"
JSON_FILE="app-repo.json"

echo "Fetching latest release data from GitHub..."

attempt=1
max_attempts=10
release_info_raw=""
release_info_clean=""

while [ "$attempt" -le "$max_attempts" ]; do
  echo "Attempt $attempt to fetch release info..."

  # fetch raw body (headers suppressed). Include User-Agent and Accept headers.
  release_info_raw=$(curl -sS \
    -H "Accept: application/vnd.github+json" \
    -H "User-Agent: NexStore-Repo-Updater" \
    "$API_URL" 2>/dev/null || true)

  if [ -z "$release_info_raw" ]; then
    echo "Empty response from API (curl returned nothing)."
  else
    # Remove control chars that break jq (U+0000..U+001F), keep newline/tab if you want:
    release_info_clean=$(printf '%s' "$release_info_raw" | tr -d '\000-\037')

    # detect API-level message (rate limit / not found / etc.)
    api_message=$(printf '%s' "$release_info_clean" | jq -r '.message // empty' 2>/dev/null || echo "")

    if [ -n "$api_message" ]; then
      echo "GitHub API message: $api_message"
      # If it's a transient message like rate limit, we still retry until attempts exhausted.
    else
      # count assets safely; default to 0 if jq fails
      assets_count=$(printf '%s' "$release_info_clean" | jq -r '(.assets // []) | length' 2>/dev/null || echo 0)

      # If assets_count is numeric and > 0, break and proceed
      # Ensure assets_count is numeric (coerce empties to 0 above)
      if [ "$(printf '%s' "$assets_count" | tr -cd '0-9')" = "" ]; then
        assets_count=0
      fi

      if [ "$assets_count" -gt 0 ]; then
        echo "Assets detected (count = $assets_count)."
        break
      else
        echo "No assets present yet (assets_count = $assets_count)."
      fi
    fi
  fi

  if [ "$attempt" -lt "$max_attempts" ]; then
    echo "No assets found yet, retrying in 5 seconds..."
    sleep 5
  fi

  attempt=$((attempt + 1))
done

# If still empty, make sure we have the cleaned variable (may be empty string)
# Use the last fetched clean value (may be empty)
if [ -z "${release_info_clean:-}" ]; then
  # make release_info_clean at least empty string to avoid "unset" failures
  release_info_clean="${release_info_raw:-}"
  # sanitize once more (safe even if empty)
  release_info_clean=$(printf '%s' "$release_info_clean" | tr -d '\000-\037')
fi

# If after retries the cleaned response is still empty, fail early with debug output
if [ -z "$release_info_clean" ]; then
  echo "Failed to fetch any release info from GitHub after $max_attempts attempts."
  echo "Last raw response (truncated):"
  printf '%s\n' "$release_info_raw" | sed -n '1,200p'
  handle_error "No valid release info available."
fi

# extract stable fields safely:
updated_at=$(printf '%s' "$release_info_clean" | jq -r '.published_at // .created_at // empty' 2>/dev/null || echo "")
# parse version in a portable way: remove leading "v" if present
tag_name=$(printf '%s' "$release_info_clean" | jq -r '.tag_name // empty' 2>/dev/null || echo "")
version=$(printf '%s' "$tag_name" | sed 's/^v//')

echo "Release version: $version"
echo "Updated at: $updated_at"

echo "Assets found (raw):"
# print asset names if any; otherwise show "(none)"
printf '%s' "$release_info_clean" | jq -r '(.assets // [])[]?.name' 2>/dev/null || echo "(none)"

# build ipa_files JSON array safely; jq errors are redirected so script continues
ipa_files=$(printf '%s' "$release_info_clean" | jq '
[
  (.assets // [])[]
  | select((.name | endswith(".ipa")) or (.name | endswith(".tipa")))
  | {
      name: .name,
      size: (.size // 0) | tonumber,
      download_url: .browser_download_url
    }
]' 2>/dev/null || echo "[]")

ipa_len=$(printf '%s' "$ipa_files" | jq -r 'length' 2>/dev/null || echo 0)

if [ "$ipa_len" -gt 0 ]; then
  echo "Found IPA/TIPA files in release:"
  printf '%s' "$ipa_files" | jq -r '.[] | "• \(.name) (\(.size) bytes)"' 2>/dev/null

  if [ ! -f "$JSON_FILE" ]; then
    handle_error "$JSON_FILE does not exist."
  fi

  num_apps=$(jq -r '.apps | length' "$JSON_FILE" 2>/dev/null || echo 0)
  echo "Repository has $num_apps apps"

  # Ensure num_apps is numeric
  if [ "$(printf '%s' "$num_apps" | tr -cd '0-9')" = "" ]; then
    num_apps=0
  fi

  i=0
  while [ "$i" -lt "$num_apps" ]; do
    app_index="$i"
    app_name=$(jq -r ".apps[$app_index].name // empty" "$JSON_FILE" 2>/dev/null || echo "")
    app_id=$(jq -r ".apps[$app_index].bundleIdentifier // empty" "$JSON_FILE" 2>/dev/null || echo "")

    echo "Processing app[$app_index]: $app_name ($app_id)"

    matching_file_json=""

    if printf '%s' "$app_name" | grep -i "idevice" >/dev/null 2>&1; then
      matching_file_json=$(printf '%s' "$ipa_files" | jq 'map(select((.name | endswith(".tipa")) or (.name | test("idevice"; "i")))) | first' 2>/dev/null || echo "null")
    else
      matching_file_json=$(printf '%s' "$ipa_files" | jq 'map(select((.name | endswith(".ipa")) and (.name | test("idevice"; "i") | not))) | first' 2>/dev/null || echo "null")
    fi

    # fallback to first file if no specific match
    if [ "$matching_file_json" = "null" ] || [ -z "$matching_file_json" ]; then
      matching_file_json=$(printf '%s' "$ipa_files" | jq 'first' 2>/dev/null || echo "null")
      echo "No specific match found for $app_name, using first available file"
    fi

    if [ "$matching_file_json" != "null" ] && [ -n "$matching_file_json" ]; then
      name=$(printf '%s' "$matching_file_json" | jq -r '.name // empty' 2>/dev/null || echo "")
      size=$(printf '%s' "$matching_file_json" | jq -r '.size // 0' 2>/dev/null || echo 0)
      download_url=$(printf '%s' "$matching_file_json" | jq -r '.download_url // empty' 2>/dev/null || echo "")

      echo "Updating $app_name with: $name"

      tmp_file="${JSON_FILE}.tmp"

      # Write updated JSON to tmp_file
      jq \
        --arg index "$app_index" \
        --arg version "$version" \
        --arg date "$updated_at" \
        --argjson size "$size" \
        --arg url "$download_url" \
        '
        .apps[$index | tonumber].version = $version |
        .apps[$index | tonumber].versionDate = $date |
        .apps[$index | tonumber].size = ($size | tonumber) |
        .apps[$index | tonumber].downloadURL = $url |
        .apps[$index | tonumber].versions = [{
          version: $version,
          date: $date,
          size: ($size | tonumber),
          downloadURL: $url
        }]
        ' "$JSON_FILE" > "$tmp_file" 2>/dev/null || {
          echo "jq update failed for $app_name — skipping."
          rm -f "$tmp_file" || true
          i=$((i + 1))
          continue
        }

      # Validate JSON before replacing
      if jq -e . "$tmp_file" >/dev/null 2>&1; then
        mv "$tmp_file" "$JSON_FILE"
        echo "Updated $JSON_FILE for $app_name"
      else
        echo "Error: JSON became invalid after update for $app_name. Not replacing."
        rm -f "$tmp_file"
      fi
    else
      echo "No matching file found for $app_name"
    fi

    i=$((i + 1))
  done

  echo "Repository update completed"
else
  echo "No .ipa or .tipa files found in the latest release."
  # Optionally print the last cleaned release JSON for debugging (truncated)
  echo "Last cleaned API response (truncated):"
  printf '%s\n' "$release_info_clean" | sed -n '1,200p'
fi
