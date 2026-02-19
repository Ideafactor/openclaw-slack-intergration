#!/usr/bin/env bash
# firewall.sh — Phase 4: UFW 방화벽 규칙
# provision.sh에서 source로 실행됩니다.

apply_firewall_rules() {
  local port=18789

  if [[ "${SKIP_FIREWALL:-false}" == "true" ]]; then
    log_info "$(msg FW_SKIP)"
    return 0
  fi

  if ! command -v ufw &>/dev/null; then
    log_warn "$(msg FW_UFW_NOT_FOUND)"
    log_warn "$(msg FW_MANUAL_BLOCK "${port}")"
    return 0
  fi

  if [[ "${DRY_RUN:-false}" == "true" ]]; then
    log_info "[DRY-RUN] ufw deny in on any to any port ${port} proto tcp"
    log_info "[DRY-RUN] ufw --force enable"
    return 0
  fi

  # root 권한 확인
  if [[ "${EUID}" -ne 0 ]] && ! sudo -n true 2>/dev/null; then
    log_warn "$(msg FW_SUDO_NEEDED)"
  fi

  log_info "$(msg FW_BLOCKING "${port}")"

  # 외부에서 포트 18789로의 TCP 접근 차단
  if ! sudo ufw deny in on any to any port "${port}" proto tcp 2>&1 | while IFS= read -r line; do log_debug "ufw: ${line}"; done; then
    log_warn "$(msg FW_RULE_FAIL "${port}")"
    return 0  # 방화벽 실패는 치명적이지 않음 (게이트웨이 바인딩으로 보호됨)
  fi

  # UFW 활성화 (이미 활성화된 경우 --force로 재확인 없이 진행)
  if ! sudo ufw --force enable 2>&1 | while IFS= read -r line; do log_debug "ufw: ${line}"; done; then
    log_warn "$(msg FW_ENABLE_FAIL)"
    return 0
  fi

  log_success "$(msg FW_DONE "${port}")"

  # 현재 UFW 상태 출력
  log_debug "$(msg FW_STATUS)"
  sudo ufw status numbered 2>/dev/null | grep "${port}" | while IFS= read -r line; do
    log_debug "  ${line}"
  done

  return 0
}

run_firewall() {
  log_phase "$(msg PHASE_FIREWALL)"

  if ! apply_firewall_rules; then
    log_warn "$(msg FW_PROBLEM)"
    log_warn "$(msg FW_GATEWAY_SECURE)"
  else
    log_success "$(msg FW_DONE_PHASE)"
  fi

  return 0  # 방화벽 실패는 치명적이지 않음
}
