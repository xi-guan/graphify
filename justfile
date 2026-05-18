set shell := ["bash", "-euo", "pipefail", "-c"]

_default:
    @just --list

# sync fork with upstream then rebase local branch
pull:
    #!/usr/bin/env bash
    set -euo pipefail
    if ! git remote get-url upstream &>/dev/null; then
        echo "adding upstream remote..."
        git remote add upstream git@github.com:safishamsi/graphify.git
    fi
    branch=$(git branch --show-current)
    echo "fetching upstream..."
    git fetch upstream
    echo "rebasing ${branch} onto upstream/${branch}..."
    git rebase "upstream/${branch}"
    echo "pushing to origin..."
    git push origin "${branch}"
    echo "✓ synced with upstream and pushed to origin/${branch}"

# set up local dev environment with uv
setup:
    #!/usr/bin/env bash
    set -euo pipefail
    if ! command -v uv &>/dev/null; then
        echo "✗ uv not found — install: curl -LsSf https://astral.sh/uv/install.sh | sh"
        exit 1
    fi
    if [ ! -d .venv ]; then
        echo "creating venv..."
        uv venv
    fi
    echo "installing graphify[all] + pytest in editable mode..."
    uv pip install -e ".[all]" pytest
    echo "✓ done — activate with: source .venv/bin/activate"

# run test suite (mirrors CI)
test *ARGS:
    python -m pytest tests/ -q --tb=short {{ ARGS }}

# show current + installed versions
version:
    #!/usr/bin/env bash
    set -euo pipefail
    pkg=$(python -c "import tomllib, pathlib; print(tomllib.loads(pathlib.Path('pyproject.toml').read_text())['project']['version'])" 2>/dev/null || echo "?")
    echo "pyproject.toml: ${pkg}"
    if command -v graphify &>/dev/null; then
        echo "installed:      $(graphify --version 2>&1 | head -1)"
    else
        echo "installed:      (not found)"
    fi

# interactively select build artifacts to remove
clean:
    #!/usr/bin/env bash
    set -euo pipefail
    command -v fzf >/dev/null || { echo "fzf required: brew install fzf"; exit 1; }
    items=()
    for d in graphifyy.egg-info dist .venv graphify-out; do
        if [[ -d "$d" ]]; then
            size=$(du -sh "$d" 2>/dev/null | cut -f1)
            items+=("${d} (${size})")
        fi
    done
    pycache=$(find . -type d -name __pycache__ 2>/dev/null | wc -l | tr -d ' ')
    if [[ "$pycache" -gt 0 ]]; then
        items+=("__pycache__ (${pycache} dirs)")
    fi
    if [[ ${#items[@]} -eq 0 ]]; then
        echo "nothing to clean."
        exit 0
    fi
    selected=$(printf '%s\n' "${items[@]}" | fzf --multi --header="Select items to remove (TAB to toggle)")
    [[ -z "$selected" ]] && exit 0
    echo ""
    echo "$selected"
    echo ""
    read -rp "remove these? [y/N] " ans
    [[ "$ans" != [yY] ]] && exit 0
    while IFS= read -r line; do
        target="${line%% (*}"
        if [[ "$target" == "__pycache__" ]]; then
            find . -type d -name __pycache__ -exec rm -rf {} + 2>/dev/null || true
        else
            rm -rf "$target"
        fi
        echo "✓ removed ${target}"
    done <<< "$selected"

# install graphify as a global CLI tool via uv
release:
    #!/usr/bin/env bash
    set -euo pipefail
    if ! command -v uv &>/dev/null; then
        echo "✗ uv not found"
        exit 1
    fi
    echo "installing graphify as global tool..."
    uv tool install --force --from . graphifyy
    echo "verifying..."
    graphify --version
    echo "✓ graphify installed globally"
