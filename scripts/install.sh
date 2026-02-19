#!/usr/bin/env bash
# install.sh — Phase 3: npm install + openclaw onboard
# provision.sh에서 source로 실행됩니다.

install_openclaw_package() {
  log_info "$(msg INST_INSTALLING)"

  if [[ "${DRY_RUN:-false}" == "true" ]]; then
    log_info "$(msg INST_DRY_NPM)"
    return 0
  fi

  if ! npm install -g openclaw@latest 2>&1 | while IFS= read -r line; do log_debug "npm: ${line}"; done; then
    log_error "$(msg INST_NPM_FAIL)"
    return 1
  fi

  # 설치 확인
  if ! command -v openclaw &>/dev/null; then
    log_error "$(msg INST_CMD_NOT_FOUND)"
    log_info  "$(msg INST_NPM_BIN "$(npm bin -g 2>/dev/null || echo 'unknown')")"
    log_info  "$(msg INST_PATH "${PATH}")"
    return 1
  fi

  local version
  version=$(openclaw --version 2>/dev/null || echo "unknown")
  log_success "$(msg INST_DONE "${version}")"
  return 0
}

run_openclaw_onboard() {
  log_info "$(msg INST_ONBOARD_START)"

  if [[ "${DRY_RUN:-false}" == "true" ]]; then
    log_info "$(msg INST_DRY_CONFIG "${STATE_DIR}")"
    log_info "$(msg INST_DRY_ONBOARD)"
    return 0
  fi

  # 설정 파일 경로 환경 변수 설정
  export OPENCLAW_CONFIG_PATH="${STATE_DIR}/openclaw.json"

  # .env 파일 로드
  if [[ -f "${STATE_DIR}/.env" ]]; then
    set -a
    # shellcheck source=/dev/null
    source "${STATE_DIR}/.env"
    set +a
    log_debug "$(msg INST_ENV_LOADED)"
  fi

  log_info "$(msg INST_ONBOARD_WAIT)"
  log_info "$(msg INST_ONBOARD_SKIP_HEALTH)"

  # timeout으로 무한 대기 방지
  # --non-interactive: 새 프롬프트 추가 시 CI 무한 대기 방지
  # --skip-health: 알려진 hang 버그 우회
  # --gateway-bind lan: LAN 바인딩
  # --install-daemon: systemd/launchd 데몬 자동 등록
  local onboard_exit=0
  timeout 120 openclaw onboard \
    --non-interactive \
    --skip-health \
    --gateway-bind lan \
    --install-daemon \
    2>&1 | while IFS= read -r line; do
      log_debug "onboard: ${line}"
    done || onboard_exit=$?

  if [[ "${onboard_exit}" -eq 124 ]]; then
    log_error "$(msg INST_ONBOARD_TIMEOUT)"
    log_info  "$(msg INST_LOG_HINT "${STATE_DIR}")"
    return 1
  elif [[ "${onboard_exit}" -ne 0 ]]; then
    log_error "$(msg INST_ONBOARD_FAIL "${onboard_exit}")"
    log_info  "$(msg INST_LOG_HINT "${STATE_DIR}")"
    return 1
  fi

  log_success "$(msg INST_ONBOARD_DONE)"
  return 0
}

run_install() {
  log_phase "$(msg PHASE_INSTALL)"

  if [[ "${FORCE:-false}" == "true" ]]; then
    log_info "$(msg INST_FORCE_REMOVE)"
    if command -v openclaw &>/dev/null; then
      openclaw gateway stop --non-interactive 2>/dev/null || true
      openclaw uninstall --all --yes --non-interactive 2>/dev/null || true
    fi
    pkill -f openclaw 2>/dev/null || true
    sleep 2
  fi

  if ! install_openclaw_package; then
    return 1
  fi

  if ! run_openclaw_onboard; then
    return 1
  fi

  log_success "$(msg INST_DONE_PHASE)"
  return 0
}
