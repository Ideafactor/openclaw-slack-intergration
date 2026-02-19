#!/usr/bin/env bash
# validate.sh — Phase 1: 입력 검증 + 의존성 체크
# provision.sh에서 source로 실행됩니다.

validate_tokens() {
  local errors=0

  # 필수 토큰 존재 확인
  if [[ -z "${SLACK_BOT_TOKEN:-}" ]]; then
    log_error "$(msg VAL_BOT_TOKEN_MISSING)"
    ((errors++))
  elif [[ ! "${SLACK_BOT_TOKEN}" =~ ^xoxb-[0-9A-Za-z-]+$ ]]; then
    log_error "$(msg VAL_BOT_TOKEN_INVALID)"
    ((errors++))
  fi

  if [[ -z "${SLACK_APP_TOKEN:-}" ]]; then
    log_error "$(msg VAL_APP_TOKEN_MISSING)"
    ((errors++))
  elif [[ ! "${SLACK_APP_TOKEN}" =~ ^xapp-[0-9A-Za-z-]+$ ]]; then
    log_error "$(msg VAL_APP_TOKEN_INVALID)"
    ((errors++))
  fi

  if [[ -z "${ANTHROPIC_API_KEY:-}" ]]; then
    log_error "$(msg VAL_ANTHROPIC_KEY_MISSING)"
    ((errors++))
  elif [[ ! "${ANTHROPIC_API_KEY}" =~ ^sk-ant-[a-zA-Z0-9_-]+$ ]]; then
    log_error "$(msg VAL_ANTHROPIC_KEY_INVALID)"
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
    log_error "$(msg VAL_DEPS_MISSING "${missing[*]}")"
    log_info  "$(msg VAL_DEPS_INSTALL_HINT "${missing[*]}" "${missing[*]}")"
  fi

  # Node.js 버전 체크 (≥18)
  if command -v node &>/dev/null; then
    local node_version
    node_version=$(node --version 2>/dev/null | sed 's/v//')
    local node_major
    node_major=$(echo "${node_version}" | cut -d. -f1)
    if [[ "${node_major}" -lt 18 ]]; then
      log_error "$(msg VAL_NODE_VERSION "${node_version}")"
      ((errors++))
    else
      log_debug "Node.js v${node_version} ✓"
    fi
  fi

  # ufw 체크 (선택적)
  if [[ "${SKIP_FIREWALL:-false}" != "true" ]]; then
    if ! command -v ufw &>/dev/null; then
      log_warn "$(msg VAL_UFW_MISSING)"
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
      log_error "$(msg VAL_PORT_IN_USE "${port}" "${pid}" "${pname}")"
      log_info  "$(msg VAL_PORT_IN_USE_HINT)"
      ((errors++))
    fi
  elif command -v ss &>/dev/null; then
    if ss -tlnp "sport = :${port}" 2>/dev/null | grep -q ":${port}"; then
      log_error "$(msg VAL_PORT_IN_USE_SIMPLE "${port}")"
      ((errors++))
    fi
  fi

  return "${errors}"
}

validate_existing_install() {
  local errors=0

  if [[ -d "${STATE_DIR}" ]] || command -v openclaw &>/dev/null; then
    if [[ "${FORCE:-false}" == "true" ]]; then
      log_warn "$(msg VAL_EXISTING_INSTALL_FORCE)"
    else
      log_error "$(msg VAL_EXISTING_INSTALL)"
      log_info  "$(msg VAL_EXISTING_INSTALL_HINT)"
      log_info  "$(msg VAL_EXISTING_INSTALL_PATH "${STATE_DIR}")"
      ((errors++))
    fi
  fi

  return "${errors}"
}

run_validate() {
  log_phase "$(msg PHASE_VALIDATE)"

  local total_errors=0

  validate_tokens       || total_errors=$((total_errors + $?))
  validate_dependencies || total_errors=$((total_errors + $?))

  if [[ "${FORCE:-false}" != "true" ]]; then
    validate_port          || total_errors=$((total_errors + $?))
    validate_existing_install || total_errors=$((total_errors + $?))
  fi

  if [[ "${total_errors}" -gt 0 ]]; then
    log_error "$(msg VAL_FAIL_COUNT "${total_errors}")"
    return 1
  fi

  log_success "$(msg VAL_DONE)"
  return 0
}
