#!/usr/bin/env bash
# validate.sh — Phase 1: 입력 검증 + 의존성 체크
# provision.sh에서 source로 실행됩니다.

validate_tokens() {
  local errors=0

  # 필수 토큰 존재 확인
  if [[ -z "${SLACK_BOT_TOKEN:-}" ]]; then
    log_error "SLACK_BOT_TOKEN이 설정되지 않았습니다. --slack-bot-token 또는 환경 변수로 제공하세요."
    ((errors++))
  elif [[ ! "${SLACK_BOT_TOKEN}" =~ ^xoxb-[0-9A-Za-z-]+$ ]]; then
    log_error "SLACK_BOT_TOKEN 형식이 올바르지 않습니다. (예: xoxb-123456789...)"
    ((errors++))
  fi

  if [[ -z "${SLACK_APP_TOKEN:-}" ]]; then
    log_error "SLACK_APP_TOKEN이 설정되지 않았습니다. --slack-app-token 또는 환경 변수로 제공하세요."
    ((errors++))
  elif [[ ! "${SLACK_APP_TOKEN}" =~ ^xapp-[0-9A-Za-z-]+$ ]]; then
    log_error "SLACK_APP_TOKEN 형식이 올바르지 않습니다. (예: xapp-1-A123...)"
    ((errors++))
  fi

  if [[ -z "${ANTHROPIC_API_KEY:-}" ]]; then
    log_error "ANTHROPIC_API_KEY가 설정되지 않았습니다. --anthropic-api-key 또는 환경 변수로 제공하세요."
    ((errors++))
  elif [[ ! "${ANTHROPIC_API_KEY}" =~ ^sk-ant-[a-zA-Z0-9_-]+$ ]]; then
    log_error "ANTHROPIC_API_KEY 형식이 올바르지 않습니다. (예: sk-ant-api03-...)"
    ((errors++))
  fi

  return "${errors}"
}

validate_dependencies() {
  local errors=0
  local missing=()

  # 필수 의존성 체크
  local required_cmds=("node" "npm" "openssl" "envsubst" "curl")
  for cmd in "${required_cmds[@]}"; do
    if ! command -v "${cmd}" &>/dev/null; then
      missing+=("${cmd}")
      ((errors++))
    fi
  done

  if [[ ${#missing[@]} -gt 0 ]]; then
    log_error "다음 명령어가 설치되지 않았습니다: ${missing[*]}"
    log_info  "설치 방법: brew install ${missing[*]}  (macOS) 또는  apt install ${missing[*]}  (Ubuntu)"
  fi

  # Node.js 버전 체크 (≥18)
  if command -v node &>/dev/null; then
    local node_version
    node_version=$(node --version 2>/dev/null | sed 's/v//')
    local node_major
    node_major=$(echo "${node_version}" | cut -d. -f1)
    if [[ "${node_major}" -lt 18 ]]; then
      log_error "Node.js 18 이상이 필요합니다. 현재: v${node_version}"
      ((errors++))
    else
      log_debug "Node.js v${node_version} ✓"
    fi
  fi

  # ufw 체크 (선택적)
  if [[ "${SKIP_FIREWALL:-false}" != "true" ]]; then
    if ! command -v ufw &>/dev/null; then
      log_warn "ufw가 설치되지 않았습니다. 방화벽 설정을 건너뜁니다. (--skip-firewall로 경고 억제 가능)"
      SKIP_FIREWALL=true
    fi
  fi

  return "${errors}"
}

validate_port() {
  local port=18789
  local errors=0

  if command -v lsof &>/dev/null; then
    if lsof -iTCP:"${port}" -sTCP:LISTEN -t &>/dev/null; then
      local pid
      pid=$(lsof -iTCP:"${port}" -sTCP:LISTEN -t 2>/dev/null | head -1)
      local pname
      pname=$(ps -p "${pid}" -o comm= 2>/dev/null || echo "unknown")
      log_error "포트 ${port}가 이미 사용 중입니다. (PID: ${pid}, 프로세스: ${pname})"
      log_info  "기존 OpenClaw 설치가 실행 중일 수 있습니다. --force 플래그를 사용하거나 uninstall.sh를 실행하세요."
      ((errors++))
    fi
  elif command -v ss &>/dev/null; then
    if ss -tlnp "sport = :${port}" 2>/dev/null | grep -q ":${port}"; then
      log_error "포트 ${port}가 이미 사용 중입니다."
      ((errors++))
    fi
  fi

  return "${errors}"
}

validate_existing_install() {
  local errors=0

  if [[ -d "${STATE_DIR}" ]] || command -v openclaw &>/dev/null; then
    if [[ "${FORCE:-false}" == "true" ]]; then
      log_warn "기존 OpenClaw 설치가 감지되었습니다. --force 플래그로 인해 제거 후 재설치합니다."
    else
      log_error "기존 OpenClaw 설치가 감지되었습니다."
      log_info  "재설치하려면 --force 플래그를 사용하거나 먼저 uninstall.sh를 실행하세요."
      log_info  "감지된 위치: ${STATE_DIR}"
      ((errors++))
    fi
  fi

  return "${errors}"
}

run_validate() {
  log_phase "Phase 1: 입력 검증 및 의존성 체크"

  local total_errors=0

  validate_tokens       || total_errors=$((total_errors + $?))
  validate_dependencies || total_errors=$((total_errors + $?))

  if [[ "${FORCE:-false}" != "true" ]]; then
    validate_port          || total_errors=$((total_errors + $?))
    validate_existing_install || total_errors=$((total_errors + $?))
  fi

  if [[ "${total_errors}" -gt 0 ]]; then
    log_error "검증 실패: ${total_errors}개의 오류가 발견되었습니다."
    return 1
  fi

  log_success "Phase 1 완료: 모든 검증 통과"
  return 0
}
