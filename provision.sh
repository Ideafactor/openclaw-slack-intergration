#!/usr/bin/env bash
# provision.sh — OpenClaw + Slack 자동 프로비저닝 메인 진입점
#
# 사용법:
#   ./provision.sh \
#     --slack-bot-token  xoxb-... \
#     --slack-app-token  xapp-... \
#     --anthropic-api-key sk-ant-... \
#     [--allow-from U12345678] \
#     [--primary-model anthropic/claude-opus-4-6] \
#     [--bot-name OpenClaw] \
#     [--state-dir ~/.openclaw] \
#     [--skip-firewall] \
#     [--skip-verify] \
#     [--force] \
#     [--dry-run] \
#     [--lang ko|en]
#
# 환경 변수로도 모든 플래그 설정 가능 (CI/CD secrets 주입 시)

set -euo pipefail

# ────────────────────────────────────────────────────────────
# 스크립트 위치 감지 (심볼릭 링크 지원)
# ────────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}" 2>/dev/null || echo "${BASH_SOURCE[0]}")")" && pwd)"
export SCRIPT_DIR

# ────────────────────────────────────────────────────────────
# 로깅 유틸리티
# ────────────────────────────────────────────────────────────
# 색상 코드
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

log_phase()   { echo -e "\n${BOLD}${CYAN}══════════════════════════════════════${NC}"; \
                echo -e "${BOLD}${CYAN}  $*${NC}"; \
                echo -e "${BOLD}${CYAN}══════════════════════════════════════${NC}"; }
log_info()    { echo -e "${BLUE}[INFO]${NC}  $*"; }
log_success() { echo -e "${GREEN}[OK]${NC}    $*"; }
log_warn()    { echo -e "${YELLOW}[WARN]${NC}  $*" >&2; }
log_error()   { echo -e "${RED}[ERROR]${NC} $*" >&2; }
log_debug()   { [[ "${VERBOSE:-false}" == "true" ]] && echo -e "        ${NC}$*" || true; }

export -f log_phase log_info log_success log_warn log_error log_debug

# ────────────────────────────────────────────────────────────
# i18n 로드 (msg 함수 — 모든 한국어/영어 메시지 출력)
# ────────────────────────────────────────────────────────────
OPENCLAW_LANG="${OPENCLAW_LANG:-}"
export OPENCLAW_LANG
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/scripts/i18n.sh"

# ────────────────────────────────────────────────────────────
# 기본값
# ────────────────────────────────────────────────────────────
SLACK_BOT_TOKEN="${SLACK_BOT_TOKEN:-}"
SLACK_APP_TOKEN="${SLACK_APP_TOKEN:-}"
ANTHROPIC_API_KEY="${ANTHROPIC_API_KEY:-}"
ALLOW_FROM=()
PRIMARY_MODEL="${PRIMARY_MODEL:-anthropic/claude-opus-4-6}"
BOT_NAME="${BOT_NAME:-OpenClaw}"
STATE_DIR="${STATE_DIR:-${HOME}/.openclaw}"
SKIP_FIREWALL="${SKIP_FIREWALL:-false}"
SKIP_VERIFY="${SKIP_VERIFY:-false}"
FORCE="${FORCE:-false}"
DRY_RUN="${DRY_RUN:-false}"
VERBOSE="${VERBOSE:-false}"

export SLACK_BOT_TOKEN SLACK_APP_TOKEN ANTHROPIC_API_KEY
export PRIMARY_MODEL BOT_NAME STATE_DIR
export SKIP_FIREWALL SKIP_VERIFY FORCE DRY_RUN VERBOSE
export ALLOW_FROM

# ────────────────────────────────────────────────────────────
# CLI 인수 파싱
# ────────────────────────────────────────────────────────────
parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --slack-bot-token)
        SLACK_BOT_TOKEN="$2"; shift 2 ;;
      --slack-app-token)
        SLACK_APP_TOKEN="$2"; shift 2 ;;
      --anthropic-api-key)
        ANTHROPIC_API_KEY="$2"; shift 2 ;;
      --allow-from)
        ALLOW_FROM+=("$2"); shift 2 ;;
      --primary-model)
        PRIMARY_MODEL="$2"; shift 2 ;;
      --bot-name)
        BOT_NAME="$2"; shift 2 ;;
      --state-dir)
        STATE_DIR="$2"; shift 2 ;;
      --skip-firewall)
        SKIP_FIREWALL=true; shift ;;
      --skip-verify)
        SKIP_VERIFY=true; shift ;;
      --force)
        FORCE=true; shift ;;
      --dry-run)
        DRY_RUN=true; shift ;;
      --verbose|-v)
        VERBOSE=true; shift ;;
      --lang)
        OPENCLAW_LANG="$2"; shift 2 ;;
      --help|-h)
        print_usage; exit 0 ;;
      *)
        log_error "$(msg PROV_UNKNOWN_OPTION "$1")"
        print_usage
        exit 1 ;;
    esac
  done

  # 재export (파싱 후 업데이트)
  export SLACK_BOT_TOKEN SLACK_APP_TOKEN ANTHROPIC_API_KEY
  export PRIMARY_MODEL BOT_NAME STATE_DIR
  export SKIP_FIREWALL SKIP_VERIFY FORCE DRY_RUN VERBOSE
  export ALLOW_FROM OPENCLAW_LANG
}

print_usage() {
  cat <<EOF

${BOLD}$(msg PROV_USAGE_HEADER)${NC}
  ./provision.sh [$(msg PROV_USAGE_OPTIONS_LABEL)]

${BOLD}$(msg PROV_USAGE_REQUIRED)${NC}
  --slack-bot-token   TOKEN    Slack Bot Token (xoxb-...)
  --slack-app-token   TOKEN    Slack App-Level Token (xapp-...)
  --anthropic-api-key KEY      Anthropic API Key (sk-ant-...)

${BOLD}$(msg PROV_USAGE_OPTIONAL)${NC}
  --allow-from        USER_ID  $(msg PROV_OPT_ALLOW_FROM_DESC)
  --primary-model     MODEL    $(msg PROV_OPT_MODEL_DESC)
  --bot-name          NAME     $(msg PROV_OPT_BOT_NAME_DESC)
  --state-dir         PATH     $(msg PROV_OPT_STATE_DIR_DESC)
  --lang              ko|en    $(msg PROV_OPT_LANG_DESC)
  --skip-firewall              $(msg PROV_OPT_SKIP_FW_DESC)
  --skip-verify                $(msg PROV_OPT_SKIP_VERIFY_DESC)
  --force                      $(msg PROV_OPT_FORCE_DESC)
  --dry-run                    $(msg PROV_OPT_DRY_RUN_DESC)
  --verbose, -v                $(msg PROV_OPT_VERBOSE_DESC)
  --help, -h                   $(msg PROV_OPT_HELP_DESC)

${BOLD}$(msg PROV_USAGE_ENV)${NC}
  $(msg PROV_USAGE_ENV_DESC)
$(msg PROV_USAGE_ENV_EXAMPLE)

${BOLD}$(msg PROV_USAGE_EXAMPLES)${NC}
  $(msg PROV_USAGE_BASIC_INSTALL)
  ./provision.sh \\
    --slack-bot-token xoxb-123... \\
    --slack-app-token xapp-1-A123... \\
    --anthropic-api-key sk-ant-...

  $(msg PROV_USAGE_ALLOW_USER)
  ./provision.sh \\
    --slack-bot-token xoxb-... \\
    --slack-app-token xapp-... \\
    --anthropic-api-key sk-ant-... \\
    --allow-from U12345678 \\
    --allow-from U87654321 \\
    --dry-run

EOF
}

# ────────────────────────────────────────────────────────────
# 배너 출력
# ────────────────────────────────────────────────────────────
print_banner() {
  echo -e "${BOLD}${CYAN}"
  cat <<'EOF'
  ╔═══════════════════════════════════════════════╗
  ║     OpenClaw + Slack Auto-Provisioning        ║
  ║     Zero-touch Setup Tool                     ║
  ╚═══════════════════════════════════════════════╝
EOF
  echo -e "${NC}"

  if [[ "${DRY_RUN}" == "true" ]]; then
    echo -e "${YELLOW}$(msg PROV_DRY_RUN_MODE)${NC}\n"
  fi

  echo -e "$(msg PROV_BOT_NAME "${BOT_NAME}")"
  echo -e "$(msg PROV_PRIMARY_MODEL "${PRIMARY_MODEL}")"
  echo -e "$(msg PROV_STATE_DIR "${STATE_DIR}")"
  if [[ ${#ALLOW_FROM[@]} -gt 0 ]]; then
    echo -e "$(msg PROV_ALLOW_USERS "${ALLOW_FROM[*]}")"
  else
    echo -e "$(msg PROV_ALLOW_USERS_NONE)"
  fi
  echo ""
}

# ────────────────────────────────────────────────────────────
# 서브스크립트 로드
# ────────────────────────────────────────────────────────────
load_scripts() {
  local scripts_dir="${SCRIPT_DIR}/scripts"

  for script in validate configure install firewall verify; do
    local script_path="${scripts_dir}/${script}.sh"
    if [[ ! -f "${script_path}" ]]; then
      log_error "$(msg PROV_SCRIPT_NOT_FOUND "${script_path}")"
      exit 1
    fi
    # shellcheck source=/dev/null
    source "${script_path}"
  done
}

# ────────────────────────────────────────────────────────────
# 완료 메시지
# ────────────────────────────────────────────────────────────
print_success_summary() {
  echo ""
  echo -e "${BOLD}${GREEN}══════════════════════════════════════════════════${NC}"
  echo -e "${BOLD}${GREEN}$(msg PROV_SUCCESS_BANNER)${NC}"
  echo -e "${BOLD}${GREEN}══════════════════════════════════════════════════${NC}"
  echo ""
  echo -e "  ${GREEN}✓${NC} $(msg PROV_SUCCESS_CONNECTED)"
  echo -e "  ${GREEN}✓${NC} $(msg PROV_SUCCESS_GATEWAY)"
  echo -e "  ${GREEN}✓${NC} $(msg PROV_SUCCESS_CONFIG "${STATE_DIR}")"
  echo ""
  echo -e "$(msg PROV_NEXT_STEPS)"
  echo -e "$(msg PROV_NEXT_DM "${BOT_NAME}")"
  if [[ ${#ALLOW_FROM[@]} -eq 0 ]]; then
    echo -e "$(msg PROV_NEXT_PAIRING)"
  else
    echo -e "$(msg PROV_NEXT_ALLOWED "${ALLOW_FROM[*]}")"
  fi
  echo -e "$(msg PROV_NEXT_UNINSTALL)"
  echo ""
  echo -e "$(msg PROV_USEFUL_CMDS)"
  echo -e "$(msg PROV_CMD_STATUS)"
  echo -e "$(msg PROV_CMD_LOG_LINUX)"
  echo -e "$(msg PROV_CMD_LOG_MACOS "${HOME}")"
  echo ""
}

# ────────────────────────────────────────────────────────────
# 메인
# ────────────────────────────────────────────────────────────
main() {
  parse_args "$@"
  load_scripts
  print_banner

  # Phase 1: 검증
  if ! run_validate; then
    echo ""
    log_error "$(msg PROV_ABORT_VALIDATE)"
    exit 1
  fi

  # Phase 2: 설정
  if ! run_configure; then
    echo ""
    log_error "$(msg PROV_ABORT_CONFIGURE)"
    exit 1
  fi

  # Phase 3: 설치
  if ! run_install; then
    echo ""
    log_error "$(msg PROV_ABORT_INSTALL)"
    exit 1
  fi

  # Phase 4: 방화벽 (실패해도 계속)
  run_firewall

  # Phase 5: 검증
  if ! run_verify; then
    echo ""
    log_warn "$(msg PROV_WARN_VERIFY)"
    log_info "$(msg PROV_INFO_CHECK_LOGS)"
    exit 2
  fi

  print_success_summary
  exit 0
}

main "$@"
