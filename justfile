set shell := ["bash", "-euo", "pipefail", "-c"]

_default:
    @just --list --unsorted --list-heading '' --list-prefix='- '

# sync fork with upstream and rebase local changes
pull:
    #!/usr/bin/env bash
    set -euo pipefail
    source scripts/lib/log.sh
    branch=$(git branch --show-current)
    # parse origin URL directly — gh repo view prefers `upstream` remote when present
    origin_repo=$(git config --get remote.origin.url | sed -E 's|.*[:/]([^/]+/[^/]+)$|\1|; s|\.git$||')
    log_info "syncing ${origin_repo} branch ${branch} from upstream"
    gh repo sync "${origin_repo}" --branch "${branch}"
    log_info "rebasing local ${branch} onto origin/${branch}"
    git pull --rebase --autostash origin "${branch}"
    log_done "pull complete"

# set up local dev environment with uv
setup:
    #!/usr/bin/env bash
    set -euo pipefail
    source scripts/lib/log.sh
    command -v uv >/dev/null || { log_error "uv not found — install: curl -LsSf https://astral.sh/uv/install.sh | sh"; exit 1; }
    [[ -d .venv ]] || { log_info "creating venv"; uv venv; }
    run_quiet "installing graphify[all] + pytest" uv pip install -e ".[all]" pytest
    log_done "setup done — activate with: source .venv/bin/activate"

# install graphify as a global CLI tool via uv
install:
    #!/usr/bin/env bash
    set -euo pipefail
    source scripts/lib/log.sh
    command -v uv >/dev/null || { log_error "uv not found"; exit 1; }
    run_quiet "installing graphify globally" uv tool install --force --from . graphifyy
    log_info "$(graphify --version)"
    log_done "graphify installed"

# uninstall + setup + install (handy after upstream bumps)
reinstall:
    @just uninstall
    @just setup
    @just install

# run test suite (mirrors CI)
test *ARGS:
    python -m pytest tests/ -q --tb=short {{ ARGS }}

# show pyproject + installed versions
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
    source scripts/lib/log.sh
    command -v fzf >/dev/null || { log_error "fzf required: brew install fzf"; exit 1; }
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
    [[ ${#items[@]} -eq 0 ]] && { log_done "nothing to clean"; exit 0; }
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
        log_done "removed ${target}"
    done <<< "$selected"

# remove global graphify installation
uninstall:
    #!/usr/bin/env bash
    set -euo pipefail
    source scripts/lib/log.sh
    command -v uv >/dev/null || { log_error "uv not found"; exit 1; }
    uv tool uninstall graphifyy
    log_done "graphify uninstalled"
