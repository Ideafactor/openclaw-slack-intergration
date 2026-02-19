#!/usr/bin/env bash
# firewall.sh — Phase 4: UFW 방화벽 규칙
# provision.sh에서 source로 실행됩니다.

apply_firewall_rules() {
  local port=18789

  if [[ "${SKIP_FIREWALL:-false}" == "true" ]]; then
    log_info "방화벽 설정 건너뜀 (--skip-firewall)"
    return 0
  fi

  if ! command -v ufw &>/dev/null; then
    log_warn "ufw를 찾을 수 없습니다. 방화벽 설정을 건너뜁니다."
    log_warn "포트 ${port}를 수동으로 차단하세요 (iptables 또는 보안 그룹 설정)."
    return 0
  fi

  if [[ "${DRY_RUN:-false}" == "true" ]]; then
    log_info "[DRY-RUN] ufw deny in on any to any port ${port} proto tcp"
    log_info "[DRY-RUN] ufw --force enable"
    return 0
  fi

  # root 권한 확인
  if [[ "${EUID}" -ne 0 ]] && ! sudo -n true 2>/dev/null; then
    log_warn "ufw 설정에 root 권한이 필요합니다. sudo를 사용합니다."
  fi

  log_info "포트 ${port} 외부 접근 차단 중..."

  # 외부에서 포트 18789로의 TCP 접근 차단
  if ! sudo ufw deny in on any to any port "${port}" proto tcp 2>&1 | while IFS= read -r line; do log_debug "ufw: ${line}"; done; then
    log_warn "ufw 규칙 추가 실패. 수동으로 포트 ${port}를 차단하세요."
    return 0  # 방화벽 실패는 치명적이지 않음 (게이트웨이 바인딩으로 보호됨)
  fi

  # UFW 활성화 (이미 활성화된 경우 --force로 재확인 없이 진행)
  if ! sudo ufw --force enable 2>&1 | while IFS= read -r line; do log_debug "ufw: ${line}"; done; then
    log_warn "ufw 활성화 실패."
    return 0
  fi

  log_success "UFW 규칙 적용 완료: 외부에서 포트 ${port} 차단"

  # 현재 UFW 상태 출력
  log_debug "UFW 상태:"
  sudo ufw status numbered 2>/dev/null | grep "${port}" | while IFS= read -r line; do
    log_debug "  ${line}"
  done

  return 0
}

run_firewall() {
  log_phase "Phase 4: 방화벽 설정"

  if ! apply_firewall_rules; then
    log_warn "방화벽 설정에 문제가 있었습니다. 계속 진행합니다."
    log_warn "게이트웨이는 127.0.0.1로만 바인딩되어 있어 기본 보안은 유지됩니다."
  else
    log_success "Phase 4 완료: 방화벽 설정 완료"
  fi

  return 0  # 방화벽 실패는 치명적이지 않음
}
