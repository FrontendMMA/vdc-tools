#!/bin/bash
# Universal batch execution of implementation plans through ralphex.
# Installed into the Docker image at /usr/local/bin/run-all-plans.
#
# Usage:
#   run-all-plans --app-slug my-app
#   run-all-plans --app-slug my-app --fast
#   run-all-plans --all
#
# Wrapper-specific flags:
#   --app-slug <slug>     run plans listed in .gen/<slug>/state.json
#   --all                 run all unfinished plans from docs/plans/
#   --fast                tasks only, without reviews
#   --review              review-only mode
#   --external            external-review-only mode
#   --no-external         disable codex external review in repo-local ralphex config
#   --force               ignore docs/plans/completed markers
#   --mark-completed      always write completed markers after success
#   --no-mark-completed   never write completed markers
#
# Any unknown args are passed through to ralphex as-is.

set -euo pipefail

print_usage() {
  cat <<'EOF'
Usage:
  run-all-plans --app-slug <slug> [ralphex args...]
  run-all-plans --all [ralphex args...]
  run-all-plans [ralphex args...]        # auto-detect one active app from .gen/

Examples:
  run-all-plans --app-slug my-app
  run-all-plans --app-slug my-app --fast
  run-all-plans --app-slug my-app --no-external
  run-all-plans --all --review

Notes:
  - README.md and TEMPLATE.md are never treated as executable plans.
  - Completed markers are stored in docs/plans/completed/.
  - By default completed markers are written only in full mode
    (not in --tasks-only/--review/--external-only).
EOF
}

has_arg() {
  local needle="$1"
  shift
  local value
  for value in "$@"; do
    if [ "$value" = "$needle" ]; then
      return 0
    fi
  done
  return 1
}

sed_inplace() {
  local expr="$1"
  local file="$2"
  local tmp
  tmp="$(mktemp)"
  sed "$expr" "$file" > "$tmp" && mv "$tmp" "$file"
}

is_reserved_plan_name() {
  local name="$1"
  [ "$name" = "README.md" ] || [ "$name" = "TEMPLATE.md" ]
}

plan_marker_path() {
  local plan_path="$1"
  printf '%s/%s\n' "$COMPLETED_DIR" "$(basename "$plan_path")"
}

is_completed_plan() {
  local plan_path="$1"
  [ -f "$(plan_marker_path "$plan_path")" ]
}

mark_plan_completed() {
  local plan_path="$1"
  local marker_path

  mkdir -p "$COMPLETED_DIR"
  marker_path="$(plan_marker_path "$plan_path")"

  {
    printf 'source=%s\n' "$plan_path"
    printf 'completed_at=%s\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
    printf 'mode=%s\n' "$EXECUTION_MODE"
  } > "$marker_path"
}

plans_from_state() {
  local state_file="$1"

  node -e '
    const fs = require("fs");
    const path = require("path");
    const stateFile = process.argv[1];
    const state = JSON.parse(fs.readFileSync(stateFile, "utf8"));
    const planFiles = state.implementationPlans?.files ?? [];
    for (const file of planFiles) {
      const resolved = path.isAbsolute(file)
        ? file
        : path.resolve(path.dirname(stateFile), "..", "..", file);
      console.log(resolved);
    }
  ' "$state_file"
}

state_has_plans() {
  local state_file="$1"

  node -e '
    const fs = require("fs");
    const state = JSON.parse(fs.readFileSync(process.argv[1], "utf8"));
    const planned = state.implementationPlans?.status === "planned";
    const files = state.implementationPlans?.files ?? [];
    process.exit(planned && files.length > 0 ? 0 : 1);
  ' "$state_file"
}

resolve_state_file() {
  if [ -n "$APP_SLUG" ]; then
    local explicit_state="$WORK_DIR/.gen/$APP_SLUG/state.json"
    if [ ! -f "$explicit_state" ]; then
      echo "State file not found: $explicit_state" >&2
      exit 1
    fi
    printf '%s\n' "$explicit_state"
    return 0
  fi

  local candidate_states=()
  local state_file

  if [ -d "$WORK_DIR/.gen" ]; then
    while IFS= read -r -d '' state_file; do
      if state_has_plans "$state_file"; then
        candidate_states+=("$state_file")
      fi
    done < <(find "$WORK_DIR/.gen" -mindepth 2 -maxdepth 2 -name state.json -print0)
  fi

  if [ "${#candidate_states[@]}" -eq 1 ]; then
    printf '%s\n' "${candidate_states[0]}"
    return 0
  fi

  if [ "${#candidate_states[@]}" -eq 0 ]; then
    echo "No planned apps found in .gen/. Use --app-slug <slug> or --all." >&2
  else
    echo "Multiple planned apps found. Use --app-slug <slug> or --all." >&2
    printf 'Candidates:\n' >&2
    printf '  - %s\n' "${candidate_states[@]}" >&2
  fi
  exit 1
}

collect_all_repo_plans() {
  local plan_path

  if [ ! -d "$PLANS_DIR" ]; then
    echo "Plans directory not found: $PLANS_DIR" >&2
    exit 1
  fi

  while IFS= read -r plan_path; do
    local plan_name
    plan_name="$(basename "$plan_path")"
    if is_reserved_plan_name "$plan_name"; then
      continue
    fi
    printf '%s\n' "$plan_path"
  done < <(find "$PLANS_DIR" -maxdepth 1 -type f -name '*.md' | sort)
}

collect_target_plans() {
  local state_file

  if [ "$RUN_ALL" = true ]; then
    collect_all_repo_plans
    return 0
  fi

  state_file="$(resolve_state_file)"
  plans_from_state "$state_file" | sort
}

if [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then
  print_usage
  exit 0
fi

WORK_DIR="${WORK_DIR:-$(pwd)}"
PLANS_DIR="$WORK_DIR/docs/plans"
COMPLETED_DIR="$PLANS_DIR/completed"
LOCAL_CONFIG_DIR="$WORK_DIR/.ralphex"
LOCAL_CONFIG="$LOCAL_CONFIG_DIR/config"
APP_SLUG=""
RUN_ALL=false
NO_EXTERNAL=false
FORCE=false
MARK_COMPLETED_MODE="auto"
RALPHEX_ARGS=(
  --config-dir "$LOCAL_CONFIG_DIR"
  --wait 5m
  --review-patience=3
  --max-external-iterations=5
  --skip-finalize
  --max-iterations=50
  --debug
)

while [ $# -gt 0 ]; do
  case "$1" in
    --)
      shift
      RALPHEX_ARGS+=("$@")
      break
      ;;
    --app-slug)
      if [ -z "${2:-}" ]; then
        echo "Missing value for --app-slug" >&2
        exit 1
      fi
      APP_SLUG="$2"
      shift 2
      ;;
    --all)
      RUN_ALL=true
      shift
      ;;
    --fast)
      RALPHEX_ARGS+=(--tasks-only)
      shift
      ;;
    --review)
      RALPHEX_ARGS+=(--review)
      shift
      ;;
    --external)
      RALPHEX_ARGS+=(--external-only)
      shift
      ;;
    --no-external)
      NO_EXTERNAL=true
      shift
      ;;
    --force)
      FORCE=true
      shift
      ;;
    --mark-completed)
      MARK_COMPLETED_MODE="always"
      shift
      ;;
    --no-mark-completed)
      MARK_COMPLETED_MODE="never"
      shift
      ;;
    -h|--help)
      print_usage
      exit 0
      ;;
    *)
      RALPHEX_ARGS+=("$1")
      shift
      ;;
  esac
done

if [ "$RUN_ALL" = true ] && [ -n "$APP_SLUG" ]; then
  echo "Use either --all or --app-slug, not both." >&2
  exit 1
fi

mkdir -p "$LOCAL_CONFIG_DIR" "$COMPLETED_DIR"
[ -f "$LOCAL_CONFIG" ] || touch "$LOCAL_CONFIG"

if [ "$NO_EXTERNAL" = true ]; then
  HAD_CODEX_LINE=false
  ORIGINAL_CODEX_VALUE=""

  if grep -q '^codex_enabled' "$LOCAL_CONFIG"; then
    HAD_CODEX_LINE=true
    ORIGINAL_CODEX_VALUE="$(grep '^codex_enabled' "$LOCAL_CONFIG")"
    sed_inplace 's/^codex_enabled.*/codex_enabled = false/' "$LOCAL_CONFIG"
  else
    [ -s "$LOCAL_CONFIG" ] && [ -n "$(tail -c 1 "$LOCAL_CONFIG")" ] && echo >> "$LOCAL_CONFIG"
    echo "codex_enabled = false" >> "$LOCAL_CONFIG"
  fi

  cleanup_config() {
    if [ "$HAD_CODEX_LINE" = true ]; then
      sed_inplace "s/^codex_enabled.*/$ORIGINAL_CODEX_VALUE/" "$LOCAL_CONFIG"
    else
      sed_inplace '/^codex_enabled = false$/d' "$LOCAL_CONFIG"
      if [ ! -s "$LOCAL_CONFIG" ]; then
        rm -f "$LOCAL_CONFIG"
      fi
    fi
  }
  trap cleanup_config EXIT
fi

COLLECTED_PLANS="$(collect_target_plans)" || exit 1

PLAN_CANDIDATES=()
while IFS= read -r plan_path; do
  [ -n "$plan_path" ] || continue
  if [ ! -f "$plan_path" ]; then
    echo "Skipping missing plan file: $plan_path" >&2
    continue
  fi
  if [ "$FORCE" = false ] && is_completed_plan "$plan_path"; then
    continue
  fi
  PLAN_CANDIDATES+=("$plan_path")
done <<< "$COLLECTED_PLANS"

if [ "${#PLAN_CANDIDATES[@]}" -eq 0 ]; then
  echo "No unfinished plans found."
  exit 0
fi

TASKS_ONLY=false
REVIEW_ONLY=false
EXTERNAL_ONLY=false

if has_arg "--tasks-only" "${RALPHEX_ARGS[@]}" || has_arg "-t" "${RALPHEX_ARGS[@]}"; then
  TASKS_ONLY=true
fi
if has_arg "--review" "${RALPHEX_ARGS[@]}" || has_arg "-r" "${RALPHEX_ARGS[@]}"; then
  REVIEW_ONLY=true
fi
if has_arg "--external-only" "${RALPHEX_ARGS[@]}" || has_arg "-e" "${RALPHEX_ARGS[@]}" || has_arg "--codex-only" "${RALPHEX_ARGS[@]}" || has_arg "-c" "${RALPHEX_ARGS[@]}"; then
  EXTERNAL_ONLY=true
fi

EXECUTION_MODE="full"
if [ "$REVIEW_ONLY" = true ]; then
  EXECUTION_MODE="review-only"
elif [ "$EXTERNAL_ONLY" = true ]; then
  EXECUTION_MODE="external-only"
elif [ "$TASKS_ONLY" = true ]; then
  EXECUTION_MODE="tasks-only"
fi

AUTO_MARK_COMPLETED=false
case "$MARK_COMPLETED_MODE" in
  always)
    AUTO_MARK_COMPLETED=true
    ;;
  never)
    AUTO_MARK_COMPLETED=false
    ;;
  auto)
    if [ "$EXECUTION_MODE" = "full" ]; then
      AUTO_MARK_COMPLETED=true
    fi
    ;;
esac

echo "Node: $(node -v)"
echo "ralphex: $(command -v ralphex)"
echo ""
echo "Execution mode: $EXECUTION_MODE"
echo "Config dir: $LOCAL_CONFIG_DIR"
if [ "$RUN_ALL" = true ]; then
  echo "Plan selection: all unfinished plans from docs/plans/"
elif [ -n "$APP_SLUG" ]; then
  echo "Plan selection: state.json for app '$APP_SLUG'"
else
  echo "Plan selection: auto-detected single planned app"
fi
echo ""
echo "Plans to execute: ${#PLAN_CANDIDATES[@]}"
for plan_path in "${PLAN_CANDIDATES[@]}"; do
  echo "  - $(basename "$plan_path")"
done
echo ""
echo "ralphex args: ${RALPHEX_ARGS[*]}"
echo ""

for index in "${!PLAN_CANDIDATES[@]}"; do
  plan_path="${PLAN_CANDIDATES[$index]}"

  echo "========================================="
  echo "  [$((index + 1))/${#PLAN_CANDIDATES[@]}] $(basename "$plan_path")"
  echo "  $(date '+%Y-%m-%d %H:%M:%S')"
  echo "========================================="
  echo ""

  ralphex "${RALPHEX_ARGS[@]}" "$plan_path"

  if [ "$AUTO_MARK_COMPLETED" = true ]; then
    mark_plan_completed "$plan_path"
  fi

  echo ""
  echo "  Completed: $(basename "$plan_path")"
  echo ""
done

echo "========================================="
echo "  All ${#PLAN_CANDIDATES[@]} plans executed!"
echo "  $(date '+%Y-%m-%d %H:%M:%S')"
echo "========================================="
