#!/usr/bin/env bash
# uninstall.sh — OpenClaw 완전 초기화 (재난 복구)
# PRD 8.1 참고
#
# 사용법:
#   ./uninstall.sh [--yes] [--state-dir ~/.openclaw] [--skip-firewall] [--lang ko|en]
#
# 경고: 이 스크립트는 OpenClaw를 완전히 제거합니다.
#        모든 설정, 토큰, 상태 데이터가 삭제됩니다.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}" 2>/dev/null || echo "${BASH_SOURCE[0]}")")" && pwd)"

# 색상 코드
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

log_info()    { echo -e "${BLUE}[INFO]${NC}  $*"; }
log_success() { echo -e "${GREEN}[OK]${NC}    $*"; }
log_warn()    { echo -e "${YELLOW}[WARN]${NC}  $*" >&2; }
log_error()   { echo -e "${RED}[ERROR]${NC} $*" >&2; }

# ────────────────────────────────────────────────────────────
# i18n 로드
# ────────────────────────────────────────────────────────────
OPENCLAW_LANG="${OPENCLAW_LANG:-}"
export OPENCLAW_LANG
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/scripts/i18n.sh"

# ────────────────────────────────────────────────────────────
# 기본값
# ────────────────────────────────────────────────────────────
YES="${YES:-false}"
STATE_DIR="${STATE_DIR:-${HOME}/.openclaw}"
SKIP_FIREWALL="${SKIP_FIREWALL:-false}"

# ────────────────────────────────────────────────────────────
# CLI 인수 파싱
# ────────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
  case "$1" in
    --yes|-y)
      YES=true; shift ;;
    --state-dir)
      STATE_DIR="$2"; shift 2 ;;
    --skip-firewall)
      SKIP_FIREWALL=true; shift ;;
    --lang)
      OPENCLAW_LANG="$2"; export OPENCLAW_LANG; shift 2 ;;
    --help|-h)
      echo "$(msg UNINST_USAGE)"
      echo ""
      echo "$(msg PROV_USAGE_OPTIONS_LABEL):"
      echo "  --yes, -y           $(msg UNINST_OPT_YES)"
      echo "  --state-dir PATH    $(msg UNINST_OPT_STATE_DIR)"
      echo "  --skip-firewall     $(msg UNINST_OPT_SKIP_FIREWALL)"
      echo "  --lang ko|en        $(msg UNINST_OPT_LANG)"
      exit 0 ;;
    *)
      log_error "$(msg UNINST_UNKNOWN_OPT "$1")"
      exit 1 ;;
  esac
done

# ────────────────────────────────────────────────────────────
# 배너
# ────────────────────────────────────────────────────────────
echo -e "${BOLD}${RED}"
echo -e "  ══════════════════════════════════════════════════"
echo -e "  $(msg UNINST_BANNER_TITLE)"
echo -e "  $(msg UNINST_BANNER_WARN)"
echo -e "  ══════════════════════════════════════════════════"
echo -e "${NC}"
echo -e "$(msg UNINST_TARGETS)"
echo -e "$(msg UNINST_TARGET_PROCESS)"
echo -e "$(msg UNINST_TARGET_NPM)"
echo -e "$(msg UNINST_TARGET_STATE_DIR "${STATE_DIR}")"
echo -e "$(msg UNINST_TARGET_RELATED_DIRS "${STATE_DIR}")"
if [[ "${SKIP_FIREWALL}" != "true" ]] && command -v ufw &>/dev/null; then
  echo -e "$(msg UNINST_TARGET_UFW)"
fi
echo ""

# ────────────────────────────────────────────────────────────
# 확인 프롬프트
# ────────────────────────────────────────────────────────────
if [[ "${YES}" != "true" ]]; then
  echo -e "${YELLOW}$(msg UNINST_CONFIRM_WARN)${NC}"
  read -r -p "$(msg UNINST_CONFIRM_PROMPT)" confirm
  case "${confirm}" in
    [yY][eE][sS]|[yY])
      echo ""
      ;;
    *)
      log_info "$(msg UNINST_CANCELLED)"
      exit 0
      ;;
  esac
fi

# ────────────────────────────────────────────────────────────
# 1. openclaw 게이트웨이 정지
# ────────────────────────────────────────────────────────────
log_info "$(msg UNINST_STEP1)"
if command -v openclaw &>/dev/null; then
  openclaw gateway stop --non-interactive 2>/dev/null || true
  log_success "$(msg UNINST_STEP1_OK)"
else
  log_warn "$(msg UNINST_CMD_NOT_FOUND)"
fi

# ────────────────────────────────────────────────────────────
# 2. openclaw uninstall (데몬 포함)
# ────────────────────────────────────────────────────────────
log_info "$(msg UNINST_STEP2)"
if command -v openclaw &>/dev/null; then
  openclaw uninstall --all --yes --non-interactive 2>/dev/null || true
  log_success "$(msg UNINST_STEP2_OK)"
else
  log_warn "$(msg UNINST_CMD_NOT_FOUND)"
fi

# systemd 서비스 직접 제거 (Linux)
if command -v systemctl &>/dev/null; then
  for service in openclaw openclaw-gateway; do
    if systemctl is-active --quiet "${service}" 2>/dev/null; then
      sudo systemctl stop "${service}" 2>/dev/null || true
    fi
    if systemctl is-enabled --quiet "${service}" 2>/dev/null; then
      sudo systemctl disable "${service}" 2>/dev/null || true
    fi
    if [[ -f "/etc/systemd/system/${service}.service" ]]; then
      sudo rm -f "/etc/systemd/system/${service}.service"
    fi
  done
  sudo systemctl daemon-reload 2>/dev/null || true
fi

# launchd 서비스 제거 (macOS)
if [[ "$(uname)" == "Darwin" ]]; then
  for plist in "${HOME}/Library/LaunchAgents/com.openclaw."*.plist; do
    if [[ -f "${plist}" ]]; then
      launchctl unload "${plist}" 2>/dev/null || true
      rm -f "${plist}"
      log_success "$(msg UNINST_LAUNCHD_REMOVED "${plist}")"
    fi
  done
fi

# ────────────────────────────────────────────────────────────
# 3. 프로세스 강제 종료
# ────────────────────────────────────────────────────────────
log_info "$(msg UNINST_STEP3)"
if pgrep -f openclaw &>/dev/null; then
  pkill -f openclaw 2>/dev/null || true
  sleep 2
  # SIGKILL 재시도
  pkill -9 -f openclaw 2>/dev/null || true
  log_success "$(msg UNINST_STEP3_OK)"
else
  log_info "$(msg UNINST_NO_PROCESS)"
fi

# ────────────────────────────────────────────────────────────
# 4. 상태 디렉터리 삭제
# ────────────────────────────────────────────────────────────
log_info "$(msg UNINST_STEP4)"

# 주 상태 디렉터리
if [[ -d "${STATE_DIR}" ]]; then
  rm -rf "${STATE_DIR}"
  log_success "$(msg UNINST_DELETED "${STATE_DIR}")"
else
  log_info "$(msg UNINST_DIR_NOT_FOUND "${STATE_DIR}")"
fi

# 관련 디렉터리 패턴
for dir in "${STATE_DIR}"-*; do
  if [[ -d "${dir}" ]]; then
    rm -rf "${dir}"
    log_success "$(msg UNINST_DELETED "${dir}")"
  fi
done

# macOS 로그 디렉터리
if [[ "$(uname)" == "Darwin" ]]; then
  local_log_dir="${HOME}/Library/Logs/openclaw"
  if [[ -d "${local_log_dir}" ]]; then
    rm -rf "${local_log_dir}"
    log_success "$(msg UNINST_DELETED "${local_log_dir}")"
  fi
fi

# ────────────────────────────────────────────────────────────
# 5. npm 패키지 제거
# ────────────────────────────────────────────────────────────
log_info "$(msg UNINST_STEP5)"
if npm list -g openclaw &>/dev/null 2>&1; then
  npm uninstall -g openclaw 2>/dev/null || true
  log_success "$(msg UNINST_STEP5_OK)"
else
  log_info "$(msg UNINST_NPM_NOT_INSTALLED)"
fi

# ────────────────────────────────────────────────────────────
# 6. UFW 방화벽 규칙 제거
# ────────────────────────────────────────────────────────────
if [[ "${SKIP_FIREWALL}" != "true" ]]; then
  log_info "$(msg UNINST_STEP6)"
  if command -v ufw &>/dev/null; then
    # 포트 18789 관련 규칙 삭제
    local rule_nums
    rule_nums=$(sudo ufw status numbered 2>/dev/null | grep "18789" | grep -oP '^\[\s*\K[0-9]+' | sort -rn)

    if [[ -n "${rule_nums}" ]]; then
      for num in ${rule_nums}; do
        sudo ufw --force delete "${num}" 2>/dev/null || true
      done
      log_success "$(msg UNINST_STEP6_OK)"
    else
      log_info "$(msg UNINST_UFW_NO_RULE)"
    fi
  else
    log_warn "$(msg UNINST_UFW_NOT_FOUND)"
  fi
else
  log_info "$(msg UNINST_STEP6_SKIP)"
fi

# ────────────────────────────────────────────────────────────
# 완료
# ────────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}${GREEN}══════════════════════════════════════════════════${NC}"
echo -e "${BOLD}${GREEN}$(msg UNINST_DONE_BANNER)${NC}"
echo -e "${BOLD}${GREEN}══════════════════════════════════════════════════${NC}"
echo ""
echo -e "$(msg UNINST_DONE_MSG)"
echo -e "$(msg UNINST_DONE_REINSTALL)"
echo ""
