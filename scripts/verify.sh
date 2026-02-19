#!/usr/bin/env bash
# verify.sh — Phase 5: 설치 후 헬스체크 (4개 레이어)
# provision.sh에서 source로 실행됩니다.

# Layer 1: 프로세스 체크
check_process() {
  log_info "  [1/4] 프로세스 체크..."

  if pgrep -f openclaw &>/dev/null; then
    local pids
    pids=$(pgrep -f openclaw | tr '\n' ' ')
    log_success "  [1/4] openclaw 프로세스 실행 중 (PID: ${pids})"
    return 0
  else
    log_error "  [1/4] openclaw 프로세스를 찾을 수 없습니다."
    log_info  "        수동 확인: pgrep -f openclaw"
    return 1
  fi
}

# Layer 2: 게이트웨이 HTTP 응답 체크 (30초 폴링)
check_gateway() {
  log_info "  [2/4] 게이트웨이 HTTP 응답 체크 (최대 30초)..."
  local url="http://127.0.0.1:18789/api/status"
  local max_attempts=30
  local attempt=0

  while [[ "${attempt}" -lt "${max_attempts}" ]]; do
    ((attempt++))
    local response
    response=$(curl -sf --max-time 2 "${url}" 2>/dev/null)
    local exit_code=$?

    if [[ "${exit_code}" -eq 0 ]]; then
      log_success "  [2/4] 게이트웨이 응답 확인 (시도 ${attempt}/${max_attempts})"
      log_debug   "        응답: ${response}"
      return 0
    fi

    if [[ "${attempt}" -lt "${max_attempts}" ]]; then
      log_debug "  [2/4] 대기 중... (${attempt}/${max_attempts})"
      sleep 1
    fi
  done

  log_error "  [2/4] 게이트웨이가 30초 내에 응답하지 않았습니다."
  log_info  "        URL: ${url}"
  log_info  "        수동 확인: curl ${url}"
  return 1
}

# Layer 3: Slack 연결 확인 (로그 패턴 검색)
check_slack_connection() {
  log_info "  [3/4] Slack 소켓 모드 연결 확인..."
  local pattern="socket.mode.connected\|socket mode connected\|Socket Mode connected\|WebSocket.*connected"
  local found=false

  # systemd 로그 확인 (Linux)
  if command -v journalctl &>/dev/null; then
    if journalctl -u openclaw --since "5 minutes ago" --no-pager 2>/dev/null | grep -qiE "${pattern}"; then
      log_success "  [3/4] Slack 소켓 모드 연결 확인 (systemd 로그)"
      found=true
    fi
  fi

  # launchd 로그 확인 (macOS)
  if [[ "${found}" == "false" ]] && [[ "$(uname)" == "Darwin" ]]; then
    local log_dir="${HOME}/Library/Logs/openclaw"
    if [[ -d "${log_dir}" ]]; then
      if find "${log_dir}" -name "*.log" -newer "${STATE_DIR}/.env" -exec grep -lqiE "${pattern}" {} \; 2>/dev/null; then
        log_success "  [3/4] Slack 소켓 모드 연결 확인 (launchd 로그)"
        found=true
      fi
    fi
  fi

  # 일반 로그 파일 확인
  if [[ "${found}" == "false" ]]; then
    local log_files=(
      "${STATE_DIR}/openclaw.log"
      "${STATE_DIR}/logs/openclaw.log"
      "/var/log/openclaw.log"
      "/tmp/openclaw.log"
    )
    for log_file in "${log_files[@]}"; do
      if [[ -f "${log_file}" ]] && grep -qiE "${pattern}" "${log_file}" 2>/dev/null; then
        log_success "  [3/4] Slack 소켓 모드 연결 확인 (${log_file})"
        found=true
        break
      fi
    done
  fi

  if [[ "${found}" == "false" ]]; then
    log_warn "  [3/4] Slack 소켓 모드 연결 로그를 확인하지 못했습니다."
    log_info  "        연결이 완료되기까지 시간이 필요할 수 있습니다."
    log_info  "        수동 확인: journalctl -u openclaw -f"
    return 1
  fi

  return 0
}

# Layer 4: 포트 격리 보안 확인
check_port_isolation() {
  log_info "  [4/4] 포트 격리 보안 확인..."
  local port=18789
  local issues=0

  # 포트가 외부 인터페이스에 바인드되지 않았는지 확인
  if command -v ss &>/dev/null; then
    # ss로 포트 바인딩 확인
    local bindings
    bindings=$(ss -tlnp "sport = :${port}" 2>/dev/null)

    if echo "${bindings}" | grep -v "127.0.0.1:${port}" | grep -q ":${port}"; then
      log_error "  [4/4] 포트 ${port}가 외부 인터페이스에 바인드되어 있습니다!"
      log_error "        보안 위험: 외부에서 게이트웨이에 직접 접근 가능"
      log_info  "        바인딩 현황:"
      echo "${bindings}" | while IFS= read -r line; do log_info "          ${line}"; done
      ((issues++))
    fi
  elif command -v lsof &>/dev/null; then
    # lsof로 포트 바인딩 확인
    local bindings
    bindings=$(lsof -iTCP:"${port}" -sTCP:LISTEN 2>/dev/null)

    if echo "${bindings}" | grep -v "127.0.0.1:${port}\|localhost:${port}" | grep -q ":${port}"; then
      log_error "  [4/4] 포트 ${port}가 외부 인터페이스에 바인드되어 있습니다!"
      ((issues++))
    fi
  else
    log_warn "  [4/4] ss/lsof를 찾을 수 없어 포트 격리를 확인할 수 없습니다."
    return 0
  fi

  # UFW 규칙 확인 (설정된 경우)
  if command -v ufw &>/dev/null && [[ "${SKIP_FIREWALL:-false}" != "true" ]]; then
    if ! sudo ufw status 2>/dev/null | grep -q "DENY.*${port}"; then
      log_warn "  [4/4] UFW에서 포트 ${port} 차단 규칙을 확인할 수 없습니다."
    fi
  fi

  if [[ "${issues}" -gt 0 ]]; then
    return 1
  fi

  log_success "  [4/4] 포트 격리 확인 완료 (127.0.0.1 전용 바인딩)"
  return 0
}

run_verify() {
  log_phase "Phase 5: 설치 검증"

  if [[ "${SKIP_VERIFY:-false}" == "true" ]]; then
    log_info "검증 단계 건너뜀 (--skip-verify)"
    return 0
  fi

  if [[ "${DRY_RUN:-false}" == "true" ]]; then
    log_info "[DRY-RUN] 검증 단계 건너뜀"
    return 0
  fi

  local total_errors=0

  check_process       || ((total_errors++))
  check_gateway       || ((total_errors++))
  check_slack_connection || ((total_errors++))
  check_port_isolation   || ((total_errors++))

  echo ""
  if [[ "${total_errors}" -eq 0 ]]; then
    log_success "Phase 5 완료: 모든 검증 통과 (4/4)"
    return 0
  elif [[ "${total_errors}" -le 1 ]]; then
    log_warn "Phase 5 완료: 일부 검증 경고 (${total_errors}/4 실패)"
    log_info "경고가 있지만 기본 기능은 동작할 수 있습니다."
    return 0
  else
    log_error "Phase 5 실패: ${total_errors}/4 검증 실패"
    log_info  "설치에 문제가 있습니다. 로그를 확인하세요."
    return 1
  fi
}
