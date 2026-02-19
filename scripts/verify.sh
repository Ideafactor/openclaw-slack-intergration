#!/usr/bin/env bash
# verify.sh — Phase 5: 설치 후 헬스체크 (4개 레이어)
# provision.sh에서 source로 실행됩니다.

# Layer 1: 프로세스 체크
check_process() {
  log_info "$(msg VFY_PROCESS_CHECK)"

  if pgrep -f openclaw &>/dev/null; then
    local pids
    pids=$(pgrep -f openclaw | tr '\n' ' ')
    log_success "$(msg VFY_PROCESS_OK "${pids}")"
    return 0
  else
    log_error "$(msg VFY_PROCESS_NOT_FOUND)"
    log_info  "$(msg VFY_PROCESS_MANUAL)"
    return 1
  fi
}

# Layer 2: 게이트웨이 HTTP 응답 체크 (30초 폴링)
check_gateway() {
  log_info "$(msg VFY_GATEWAY_CHECK)"
  local url="http://127.0.0.1:18789/api/status"
  local max_attempts=30
  local attempt=0

  while [[ "${attempt}" -lt "${max_attempts}" ]]; do
    ((attempt++))
    local response
    response=$(curl -sf --max-time 2 "${url}" 2>/dev/null)
    local exit_code=$?

    if [[ "${exit_code}" -eq 0 ]]; then
      log_success "$(msg VFY_GATEWAY_OK "${attempt}" "${max_attempts}")"
      log_debug   "$(msg VFY_GATEWAY_RESPONSE "${response}")"
      return 0
    fi

    if [[ "${attempt}" -lt "${max_attempts}" ]]; then
      log_debug "$(msg VFY_GATEWAY_WAITING "${attempt}" "${max_attempts}")"
      sleep 1
    fi
  done

  log_error "$(msg VFY_GATEWAY_TIMEOUT)"
  log_info  "$(msg VFY_GATEWAY_URL "${url}")"
  log_info  "$(msg VFY_GATEWAY_MANUAL "${url}")"
  return 1
}

# Layer 3: Slack 연결 확인 (로그 패턴 검색)
check_slack_connection() {
  log_info "$(msg VFY_SLACK_CHECK)"
  local pattern="socket.mode.connected\|socket mode connected\|Socket Mode connected\|WebSocket.*connected"
  local found=false

  # systemd 로그 확인 (Linux)
  if command -v journalctl &>/dev/null; then
    if journalctl -u openclaw --since "5 minutes ago" --no-pager 2>/dev/null | grep -qiE "${pattern}"; then
      log_success "$(msg VFY_SLACK_OK_SYSTEMD)"
      found=true
    fi
  fi

  # launchd 로그 확인 (macOS)
  if [[ "${found}" == "false" ]] && [[ "$(uname)" == "Darwin" ]]; then
    local log_dir="${HOME}/Library/Logs/openclaw"
    if [[ -d "${log_dir}" ]]; then
      if find "${log_dir}" -name "*.log" -newer "${STATE_DIR}/.env" -exec grep -lqiE "${pattern}" {} \; 2>/dev/null; then
        log_success "$(msg VFY_SLACK_OK_LAUNCHD)"
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
        log_success "$(msg VFY_SLACK_OK_FILE "${log_file}")"
        found=true
        break
      fi
    done
  fi

  if [[ "${found}" == "false" ]]; then
    log_warn "$(msg VFY_SLACK_NOT_FOUND)"
    log_info  "$(msg VFY_SLACK_WAIT)"
    log_info  "$(msg VFY_SLACK_MANUAL)"
    return 1
  fi

  return 0
}

# Layer 4: 포트 격리 보안 확인
check_port_isolation() {
  log_info "$(msg VFY_PORT_CHECK)"
  local port=18789
  local issues=0

  # 포트가 외부 인터페이스에 바인드되지 않았는지 확인
  if command -v ss &>/dev/null; then
    # ss로 포트 바인딩 확인
    local bindings
    bindings=$(ss -tlnp "sport = :${port}" 2>/dev/null)

    if echo "${bindings}" | grep -v "127.0.0.1:${port}" | grep -q ":${port}"; then
      log_error "$(msg VFY_PORT_EXPOSED "${port}")"
      log_error "$(msg VFY_PORT_EXPOSED_RISK)"
      log_info  "$(msg VFY_PORT_BINDINGS)"
      echo "${bindings}" | while IFS= read -r line; do log_info "          ${line}"; done
      ((issues++))
    fi
  elif command -v lsof &>/dev/null; then
    # lsof로 포트 바인딩 확인
    local bindings
    bindings=$(lsof -iTCP:"${port}" -sTCP:LISTEN 2>/dev/null)

    if echo "${bindings}" | grep -v "127.0.0.1:${port}\|localhost:${port}" | grep -q ":${port}"; then
      log_error "$(msg VFY_PORT_EXPOSED "${port}")"
      ((issues++))
    fi
  else
    log_warn "$(msg VFY_PORT_NO_TOOL)"
    return 0
  fi

  # UFW 규칙 확인 (설정된 경우)
  if command -v ufw &>/dev/null && [[ "${SKIP_FIREWALL:-false}" != "true" ]]; then
    if ! sudo ufw status 2>/dev/null | grep -q "DENY.*${port}"; then
      log_warn "$(msg VFY_UFW_RULE_NOT_FOUND "${port}")"
    fi
  fi

  if [[ "${issues}" -gt 0 ]]; then
    return 1
  fi

  log_success "$(msg VFY_PORT_OK)"
  return 0
}

run_verify() {
  log_phase "$(msg PHASE_VERIFY)"

  if [[ "${SKIP_VERIFY:-false}" == "true" ]]; then
    log_info "$(msg VFY_SKIP)"
    return 0
  fi

  if [[ "${DRY_RUN:-false}" == "true" ]]; then
    log_info "$(msg VFY_DRY_SKIP)"
    return 0
  fi

  local total_errors=0

  check_process       || ((total_errors++))
  check_gateway       || ((total_errors++))
  check_slack_connection || ((total_errors++))
  check_port_isolation   || ((total_errors++))

  echo ""
  if [[ "${total_errors}" -eq 0 ]]; then
    log_success "$(msg VFY_DONE)"
    return 0
  elif [[ "${total_errors}" -le 1 ]]; then
    log_warn "$(msg VFY_WARN "${total_errors}")"
    log_info "$(msg VFY_WARN_INFO)"
    return 0
  else
    log_error "$(msg VFY_FAIL "${total_errors}")"
    log_info  "$(msg VFY_FAIL_INFO)"
    return 1
  fi
}
