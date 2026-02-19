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
#     [--dry-run]
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
      --help|-h)
        print_usage; exit 0 ;;
      *)
        log_error "알 수 없는 옵션: $1"
        print_usage
        exit 1 ;;
    esac
  done

  # 재export (파싱 후 업데이트)
  export SLACK_BOT_TOKEN SLACK_APP_TOKEN ANTHROPIC_API_KEY
  export PRIMARY_MODEL BOT_NAME STATE_DIR
  export SKIP_FIREWALL SKIP_VERIFY FORCE DRY_RUN VERBOSE
  export ALLOW_FROM
}

print_usage() {
  cat <<EOF

${BOLD}사용법:${NC}
  ./provision.sh [옵션]

${BOLD}필수 옵션:${NC}
  --slack-bot-token   TOKEN    Slack Bot Token (xoxb-...)
  --slack-app-token   TOKEN    Slack App-Level Token (xapp-...)
  --anthropic-api-key KEY      Anthropic API Key (sk-ant-...)

${BOLD}선택 옵션:${NC}
  --allow-from        USER_ID  허용할 Slack Member ID (여러 번 사용 가능)
  --primary-model     MODEL    기본 AI 모델 (기본값: anthropic/claude-opus-4-6)
  --bot-name          NAME     봇 이름 (기본값: OpenClaw)
  --state-dir         PATH     설정 저장 경로 (기본값: ~/.openclaw)
  --skip-firewall              UFW 설정 건너뜀
  --skip-verify                검증 단계 건너뜀
  --force                      기존 설치 제거 후 재설치
  --dry-run                    실제 실행 없이 출력만
  --verbose, -v                상세 로그 출력
  --help, -h                   도움말 표시

${BOLD}환경 변수:${NC}
  모든 옵션은 동일한 이름의 환경 변수로 대체 가능합니다.
  예: SLACK_BOT_TOKEN=xoxb-... ./provision.sh

${BOLD}예시:${NC}
  # 기본 설치
  ./provision.sh \\
    --slack-bot-token xoxb-123... \\
    --slack-app-token xapp-1-A123... \\
    --anthropic-api-key sk-ant-...

  # 특정 사용자 허용 + dry-run
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
    echo -e "${YELLOW}  ⚠  DRY-RUN 모드: 실제 변경 없음${NC}\n"
  fi

  echo -e "  봇 이름:      ${BOT_NAME}"
  echo -e "  기본 모델:    ${PRIMARY_MODEL}"
  echo -e "  상태 디렉터리: ${STATE_DIR}"
  if [[ ${#ALLOW_FROM[@]} -gt 0 ]]; then
    echo -e "  허용 사용자:  ${ALLOW_FROM[*]}"
  else
    echo -e "  허용 사용자:  (없음 — 페어링 필요)"
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
      log_error "스크립트 파일을 찾을 수 없습니다: ${script_path}"
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
  echo -e "${BOLD}${GREEN}╔═══════════════════════════════════════════════╗${NC}"
  echo -e "${BOLD}${GREEN}║     OpenClaw 프로비저닝 완료!                 ║${NC}"
  echo -e "${BOLD}${GREEN}╚═══════════════════════════════════════════════╝${NC}"
  echo ""
  echo -e "  ${GREEN}✓${NC} OpenClaw이 Slack과 소켓 모드로 연결되었습니다."
  echo -e "  ${GREEN}✓${NC} 게이트웨이: http://127.0.0.1:18789 (로컬 전용)"
  echo -e "  ${GREEN}✓${NC} 설정 파일: ${STATE_DIR}/openclaw.json"
  echo ""
  echo -e "  ${BOLD}다음 단계:${NC}"
  echo -e "  1. Slack에서 @${BOT_NAME}에게 DM을 보내 테스트하세요."
  if [[ ${#ALLOW_FROM[@]} -eq 0 ]]; then
    echo -e "  2. 첫 사용자는 페어링 코드로 인증이 필요합니다."
  else
    echo -e "  2. 허용된 사용자(${ALLOW_FROM[*]})는 바로 사용 가능합니다."
  fi
  echo -e "  3. 완전 제거: ./uninstall.sh"
  echo ""
  echo -e "  ${BOLD}유용한 명령어:${NC}"
  echo -e "  • 상태 확인:  curl http://127.0.0.1:18789/api/status"
  echo -e "  • 로그 확인:  journalctl -u openclaw -f  (Linux)"
  echo -e "              cat ${HOME}/Library/Logs/openclaw/  (macOS)"
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
    log_error "프로비저닝 중단: 검증 실패"
    exit 1
  fi

  # Phase 2: 설정
  if ! run_configure; then
    echo ""
    log_error "프로비저닝 중단: 설정 파일 렌더링 실패"
    exit 1
  fi

  # Phase 3: 설치
  if ! run_install; then
    echo ""
    log_error "프로비저닝 중단: 설치 실패"
    exit 1
  fi

  # Phase 4: 방화벽 (실패해도 계속)
  run_firewall

  # Phase 5: 검증
  if ! run_verify; then
    echo ""
    log_warn "프로비저닝 완료되었으나 일부 검증 실패"
    log_info "로그를 확인하고 수동으로 상태를 점검하세요."
    exit 2
  fi

  print_success_summary
  exit 0
}

main "$@"
