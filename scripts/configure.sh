#!/usr/bin/env bash
# configure.sh — Phase 2: 템플릿 렌더링
# provision.sh에서 source로 실행됩니다.

build_allow_from_json() {
  # ALLOW_FROM 배열을 JSON 배열 문자열로 변환
  # 예: ("U123" "U456") → ["U123","U456"]
  if [[ ${#ALLOW_FROM[@]} -eq 0 ]]; then
    echo "[]"
    return
  fi

  local json="["
  local first=true
  for member_id in "${ALLOW_FROM[@]}"; do
    if [[ "${first}" == "true" ]]; then
      first=false
    else
      json+=","
    fi
    # 특수문자 이스케이프
    local escaped
    escaped=$(printf '%s' "${member_id}" | sed 's/"/\\"/g')
    json+="\"${escaped}\""
  done
  json+="]"
  echo "${json}"
}

render_templates() {
  local template_dir="${SCRIPT_DIR}/templates"
  local state_dir="${STATE_DIR}"

  # 상태 디렉터리 생성
  mkdir -p "${state_dir}"
  chmod 700 "${state_dir}"

  # 게이트웨이 토큰 자동 생성
  OPENCLAW_GATEWAY_TOKEN=$(openssl rand -hex 32)
  log_debug "게이트웨이 토큰 생성 완료"

  # allowFrom JSON 배열 생성
  export OPENCLAW_ALLOW_FROM_JSON
  OPENCLAW_ALLOW_FROM_JSON=$(build_allow_from_json)
  log_debug "allowFrom JSON: ${OPENCLAW_ALLOW_FROM_JSON}"

  # 환경 변수 export (envsubst용)
  export SLACK_BOT_TOKEN
  export SLACK_APP_TOKEN
  export ANTHROPIC_API_KEY
  export OPENCLAW_GATEWAY_TOKEN
  export OPENCLAW_CONFIG_PATH="${state_dir}/openclaw.json"
  export OPENCLAW_BOT_NAME="${BOT_NAME}"
  export OPENCLAW_MODEL_CHAT="${PRIMARY_MODEL}"
  export OPENCLAW_MODEL_QUICK="anthropic/claude-sonnet-4-6"
  export OPENCLAW_MODEL_CHEAP="gpt-3.5-turbo"
  export OPENCLAW_STATE_DIR="${state_dir}"

  log_info "템플릿 렌더링 중..."

  # 1. .env 파일 렌더링
  if [[ "${DRY_RUN:-false}" == "true" ]]; then
    log_info "[DRY-RUN] .env 파일 생성 예정: ${state_dir}/.env"
    log_info "[DRY-RUN] openclaw.json 파일 생성 예정: ${state_dir}/openclaw.json"
    log_info "[DRY-RUN] slack-manifest.yaml 파일 생성 예정: ${state_dir}/slack-manifest.yaml"
    log_info "[DRY-RUN] OPENCLAW_ALLOW_FROM_JSON=${OPENCLAW_ALLOW_FROM_JSON}"
    return 0
  fi

  envsubst < "${template_dir}/env.template" > "${state_dir}/.env"
  chmod 600 "${state_dir}/.env"
  log_debug ".env 파일 생성: ${state_dir}/.env (chmod 600)"

  # 2. openclaw.json 렌더링
  envsubst < "${template_dir}/openclaw.json.template" > "${state_dir}/openclaw.json"
  chmod 600 "${state_dir}/openclaw.json"
  log_debug "openclaw.json 생성: ${state_dir}/openclaw.json (chmod 600)"

  # 3. JSON 유효성 검증
  if ! node -e "JSON.parse(require('fs').readFileSync('${state_dir}/openclaw.json', 'utf8'))" 2>/dev/null; then
    log_error "생성된 openclaw.json이 유효하지 않습니다."
    log_info  "파일 내용:"
    cat "${state_dir}/openclaw.json" >&2
    return 1
  fi
  log_debug "openclaw.json JSON 유효성 검증 통과"

  # 4. slack-manifest.yaml 렌더링 (참고용)
  envsubst < "${template_dir}/slack-manifest.yaml.template" > "${state_dir}/slack-manifest.yaml"
  chmod 644 "${state_dir}/slack-manifest.yaml"
  log_debug "slack-manifest.yaml 생성: ${state_dir}/slack-manifest.yaml"

  return 0
}

run_configure() {
  log_phase "Phase 2: 설정 파일 렌더링"

  if ! render_templates; then
    log_error "설정 파일 렌더링 실패"
    return 1
  fi

  if [[ "${DRY_RUN:-false}" != "true" ]]; then
    log_success "Phase 2 완료: 설정 파일 생성됨 → ${STATE_DIR}"
  else
    log_success "Phase 2 완료 (dry-run)"
  fi
  return 0
}
