#!/usr/bin/env bash
# uninstall.sh — OpenClaw 완전 초기화 (재난 복구)
# PRD 8.1 참고
#
# 사용법:
#   ./uninstall.sh [--yes] [--state-dir ~/.openclaw] [--skip-firewall]
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
    --help|-h)
      echo "사용법: ./uninstall.sh [--yes] [--state-dir PATH] [--skip-firewall]"
      echo ""
      echo "옵션:"
      echo "  --yes, -y           확인 프롬프트 없이 실행"
      echo "  --state-dir PATH    삭제할 상태 디렉터리 (기본값: ~/.openclaw)"
      echo "  --skip-firewall     UFW 규칙 제거 건너뜀"
      exit 0 ;;
    *)
      log_error "알 수 없는 옵션: $1"
      exit 1 ;;
  esac
done

# ────────────────────────────────────────────────────────────
# 배너
# ────────────────────────────────────────────────────────────
echo -e "${BOLD}${RED}"
cat <<'EOF'
  ╔═══════════════════════════════════════════════╗
  ║     OpenClaw 완전 제거 (Uninstall)            ║
  ║     이 작업은 되돌릴 수 없습니다.            ║
  ╚═══════════════════════════════════════════════╝
EOF
echo -e "${NC}"
echo -e "  제거 대상:"
echo -e "  • openclaw 프로세스 종료"
echo -e "  • openclaw npm 패키지 제거"
echo -e "  • 상태 디렉터리: ${STATE_DIR}"
echo -e "  • 관련 디렉터리: ${STATE_DIR}-*"
if [[ "${SKIP_FIREWALL}" != "true" ]] && command -v ufw &>/dev/null; then
  echo -e "  • UFW 포트 18789 규칙 제거"
fi
echo ""

# ────────────────────────────────────────────────────────────
# 확인 프롬프트
# ────────────────────────────────────────────────────────────
if [[ "${YES}" != "true" ]]; then
  echo -e "${YELLOW}경고: 이 작업은 모든 OpenClaw 데이터를 영구적으로 삭제합니다.${NC}"
  read -r -p "계속하시겠습니까? [y/N] " confirm
  case "${confirm}" in
    [yY][eE][sS]|[yY])
      echo ""
      ;;
    *)
      log_info "취소되었습니다."
      exit 0
      ;;
  esac
fi

# ────────────────────────────────────────────────────────────
# 1. openclaw 게이트웨이 정지
# ────────────────────────────────────────────────────────────
log_info "1/6 openclaw 게이트웨이 정지 중..."
if command -v openclaw &>/dev/null; then
  openclaw gateway stop --non-interactive 2>/dev/null || true
  log_success "게이트웨이 정지 명령 전송"
else
  log_warn "openclaw 명령어를 찾을 수 없습니다. 건너뜁니다."
fi

# ────────────────────────────────────────────────────────────
# 2. openclaw uninstall (데몬 포함)
# ────────────────────────────────────────────────────────────
log_info "2/6 openclaw 데몬 제거 중..."
if command -v openclaw &>/dev/null; then
  openclaw uninstall --all --yes --non-interactive 2>/dev/null || true
  log_success "openclaw 데몬 제거 완료"
else
  log_warn "openclaw 명령어를 찾을 수 없습니다. 건너뜁니다."
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
      log_success "launchd 서비스 제거: ${plist}"
    fi
  done
fi

# ────────────────────────────────────────────────────────────
# 3. 프로세스 강제 종료
# ────────────────────────────────────────────────────────────
log_info "3/6 openclaw 프로세스 강제 종료 중..."
if pgrep -f openclaw &>/dev/null; then
  pkill -f openclaw 2>/dev/null || true
  sleep 2
  # SIGKILL 재시도
  pkill -9 -f openclaw 2>/dev/null || true
  log_success "openclaw 프로세스 종료 완료"
else
  log_info "실행 중인 openclaw 프로세스 없음"
fi

# ────────────────────────────────────────────────────────────
# 4. 상태 디렉터리 삭제
# ────────────────────────────────────────────────────────────
log_info "4/6 상태 디렉터리 삭제 중..."

# 주 상태 디렉터리
if [[ -d "${STATE_DIR}" ]]; then
  rm -rf "${STATE_DIR}"
  log_success "삭제: ${STATE_DIR}"
else
  log_info "${STATE_DIR} 디렉터리 없음"
fi

# 관련 디렉터리 패턴
for dir in "${STATE_DIR}"-*; do
  if [[ -d "${dir}" ]]; then
    rm -rf "${dir}"
    log_success "삭제: ${dir}"
  fi
done

# macOS 로그 디렉터리
if [[ "$(uname)" == "Darwin" ]]; then
  local_log_dir="${HOME}/Library/Logs/openclaw"
  if [[ -d "${local_log_dir}" ]]; then
    rm -rf "${local_log_dir}"
    log_success "삭제: ${local_log_dir}"
  fi
fi

# ────────────────────────────────────────────────────────────
# 5. npm 패키지 제거
# ────────────────────────────────────────────────────────────
log_info "5/6 openclaw npm 패키지 제거 중..."
if npm list -g openclaw &>/dev/null 2>&1; then
  npm uninstall -g openclaw 2>/dev/null || true
  log_success "npm 패키지 제거 완료"
else
  log_info "openclaw npm 패키지가 설치되지 않음"
fi

# ────────────────────────────────────────────────────────────
# 6. UFW 방화벽 규칙 제거
# ────────────────────────────────────────────────────────────
if [[ "${SKIP_FIREWALL}" != "true" ]]; then
  log_info "6/6 UFW 방화벽 규칙 제거 중..."
  if command -v ufw &>/dev/null; then
    # 포트 18789 관련 규칙 삭제
    # ufw status numberedで番号を取得して削除
    local rule_nums
    rule_nums=$(sudo ufw status numbered 2>/dev/null | grep "18789" | grep -oP '^\[\s*\K[0-9]+' | sort -rn)

    if [[ -n "${rule_nums}" ]]; then
      for num in ${rule_nums}; do
        sudo ufw --force delete "${num}" 2>/dev/null || true
      done
      log_success "UFW 포트 18789 규칙 제거 완료"
    else
      log_info "UFW에서 포트 18789 관련 규칙 없음"
    fi
  else
    log_warn "ufw를 찾을 수 없습니다. 방화벽 규칙 제거 건너뜀."
  fi
else
  log_info "6/6 방화벽 규칙 제거 건너뜀 (--skip-firewall)"
fi

# ────────────────────────────────────────────────────────────
# 완료
# ────────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}${GREEN}╔═══════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}${GREEN}║     OpenClaw 제거 완료                        ║${NC}"
echo -e "${BOLD}${GREEN}╚═══════════════════════════════════════════════╝${NC}"
echo ""
echo -e "  OpenClaw이 완전히 제거되었습니다."
echo -e "  재설치하려면 ./provision.sh를 다시 실행하세요."
echo ""
