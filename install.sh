#!/usr/bin/env bash
set -euo pipefail

REPO="FrontendMMA/vdc-tools"
VDC_ROOT="${VDC_ROOT:-${HOME}/.vdc-tools}"
SRC_DIR="${VDC_ROOT}/src"
BIN_DIR="${HOME}/.local/bin"

# --- Check Docker ---
if ! command -v docker >/dev/null 2>&1; then
  echo "Docker is required. Install it first: https://docs.docker.com/get-docker/" >&2
  exit 1
fi

# --- Download / update source ---
if [ -d "${SRC_DIR}/.git" ]; then
  echo "Updating vdc-tools..."
  git -C "${SRC_DIR}" pull --ff-only 2>/dev/null || true
elif command -v git >/dev/null 2>&1; then
  echo "Installing vdc-tools..."
  git clone --depth 1 "https://github.com/${REPO}.git" "${SRC_DIR}"
else
  echo "Installing vdc-tools (without git)..."
  TMP_DIR="$(mktemp -d)"
  trap 'rm -rf "${TMP_DIR}"' EXIT
  curl -sL "https://github.com/${REPO}/archive/refs/heads/main.tar.gz" | tar xz -C "${TMP_DIR}"
  mkdir -p "$(dirname "${SRC_DIR}")"
  mv "${TMP_DIR}"/vdc-tools-* "${SRC_DIR}"
fi

# --- Create directory structure ---
for dir in knowledge mcp projects state pnpm-store; do
  mkdir -p "${VDC_ROOT}/${dir}"
done
mkdir -p "${BIN_DIR}"

# --- Create symlinks ---
for cmd in vdc-claude vdc-litellm vdc-ralphex vdc-update vdc-setup; do
  src="${SRC_DIR}/bin/${cmd}"
  dest="${BIN_DIR}/${cmd}"
  if [ -L "${dest}" ] || [ -e "${dest}" ]; then
    rm -f "${dest}"
  fi
  ln -s "${src}" "${dest}"
done

# --- Copy .env template if missing ---
if [ ! -f "${VDC_ROOT}/.env" ]; then
  cp "${SRC_DIR}/.env.example" "${VDC_ROOT}/.env"
fi

# --- Copy example files ---
copy_if_missing() {
  [ ! -f "$2" ] && cp "$1" "$2"
}

copy_if_missing "${SRC_DIR}/knowledge/README.md" "${VDC_ROOT}/knowledge/README.md"
copy_if_missing "${SRC_DIR}/examples/mcp.json.example" "${VDC_ROOT}/mcp/mcp.json.example"
copy_if_missing "${SRC_DIR}/examples/litellm.config.example.yaml" "${VDC_ROOT}/state/litellm.config.example.yaml"

# --- Ensure PATH ---
SHELL_PROFILE=""
for candidate in "${HOME}/.zshrc" "${HOME}/.bashrc" "${HOME}/.bash_profile"; do
  if [ -f "${candidate}" ] || [[ "${candidate}" == *".zshrc" ]]; then
    SHELL_PROFILE="${candidate}"
    break
  fi
done

if [ -n "${SHELL_PROFILE}" ]; then
  if ! grep -Fq '/.local/bin' "${SHELL_PROFILE}" 2>/dev/null; then
    printf '\n# vdc-tools\nexport PATH="${HOME}/.local/bin:$PATH"\n' >> "${SHELL_PROFILE}"
  fi
fi

# --- Done ---
echo ""
echo "vdc-tools installed!"
echo ""
echo "Commands: vdc-claude, vdc-litellm, vdc-ralphex, vdc-setup, vdc-update"
echo "Config:   ${VDC_ROOT}/.env"
echo ""
echo "Run 'vdc-setup' to configure your LLM backend, then:"
echo "  vdc-claude --model Qwen3.5-35B-A3B"
