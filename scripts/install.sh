#!/usr/bin/env bash
# install.sh — Phase 3: npm install + openclaw onboard
# provision.sh에서 source로 실행됩니다.

install_openclaw_package() {
  log_info "openclaw 패키지 설치 중..."

  if [[ "${DRY_RUN:-false}" == "true" ]]; then
    log_info "[DRY-RUN] npm install -g openclaw@latest"
    return 0
  fi

  if ! npm install -g openclaw@latest 2>&1 | while IFS= read -r line; do log_debug "npm: ${line}"; done; then
    log_error "npm install -g openclaw@latest 실패"
    return 1
  fi

  # 설치 확인
  if ! command -v openclaw &>/dev/null; then
    log_error "openclaw 명령어를 찾을 수 없습니다. npm global bin 경로를 확인하세요."
    log_info  "npm bin 경로: $(npm bin -g 2>/dev/null || echo 'unknown')"
    log_info  "PATH: ${PATH}"
    return 1
  fi

  local version
  version=$(openclaw --version 2>/dev/null || echo "unknown")
  log_success "openclaw 설치 완료 (버전: ${version})"
  return 0
}

run_openclaw_onboard() {
  log_info "openclaw onboard 실행 중..."

  if [[ "${DRY_RUN:-false}" == "true" ]]; then
    log_info "[DRY-RUN] OPENCLAW_CONFIG_PATH=${STATE_DIR}/openclaw.json"
    log_info "[DRY-RUN] timeout 120 openclaw onboard --non-interactive --skip-health --gateway-bind lan --install-daemon"
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
    log_debug ".env 파일 로드 완료"
  fi

  log_info "onboard 시작 (최대 120초 대기)..."
  log_info "알려진 WebSocket 헬스체크 hang 버그(GitHub #7976) 우회를 위해 --skip-health 사용"

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
    log_error "openclaw onboard가 120초 내에 완료되지 않았습니다 (타임아웃)"
    log_info  "로그 확인: journalctl -u openclaw 또는 ${STATE_DIR}/openclaw.log"
    return 1
  elif [[ "${onboard_exit}" -ne 0 ]]; then
    log_error "openclaw onboard 실패 (종료 코드: ${onboard_exit})"
    log_info  "로그 확인: journalctl -u openclaw 또는 ${STATE_DIR}/openclaw.log"
    return 1
  fi

  log_success "openclaw onboard 완료"
  return 0
}

run_install() {
  log_phase "Phase 3: OpenClaw 설치"

  if [[ "${FORCE:-false}" == "true" ]]; then
    log_info "기존 설치 제거 중 (--force)..."
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

  log_success "Phase 3 완료: OpenClaw 설치 및 초기화 완료"
  return 0
}
