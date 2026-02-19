#!/usr/bin/env bash
# i18n.sh — 다국어 지원 (ko / en)
# provision.sh / uninstall.sh에서 source로 로드됩니다.
#
# 사용법:
#   source "${SCRIPT_DIR}/scripts/i18n.sh"
#   msg KEY [format-args...]
#
# OPENCLAW_LANG 환경 변수로 언어 강제 지정 가능.
# 미설정 시 시스템 $LANG에서 자동 감지 (ko_* → ko, 그 외 → en).

# ────────────────────────────────────────────────────────────
# 언어 자동 감지
# ────────────────────────────────────────────────────────────
detect_lang() {
  local sys_lang="${OPENCLAW_LANG:-${LANG:-en}}"
  if [[ "${sys_lang}" == ko* ]]; then
    echo "ko"
  else
    echo "en"
  fi
}

OPENCLAW_LANG="${OPENCLAW_LANG:-$(detect_lang)}"
export OPENCLAW_LANG

# ────────────────────────────────────────────────────────────
# msg KEY [arg...] — 번역된 메시지 출력
#   인자가 있으면 printf 포맷 치환 (%s), 없으면 echo
# ────────────────────────────────────────────────────────────
msg() {
  local key="$1"
  local lang="${OPENCLAW_LANG:-en}"
  shift
  local text

  case "${lang}:${key}" in

    # ── Phase 헤더 ──────────────────────────────────────────
    ko:PHASE_VALIDATE)   text="Phase 1: 입력 검증 및 의존성 체크" ;;
    en:PHASE_VALIDATE)   text="Phase 1: Input validation & dependency check" ;;

    ko:PHASE_CONFIGURE)  text="Phase 2: 설정 파일 렌더링" ;;
    en:PHASE_CONFIGURE)  text="Phase 2: Rendering configuration files" ;;

    ko:PHASE_INSTALL)    text="Phase 3: OpenClaw 설치" ;;
    en:PHASE_INSTALL)    text="Phase 3: Installing OpenClaw" ;;

    ko:PHASE_FIREWALL)   text="Phase 4: 방화벽 설정" ;;
    en:PHASE_FIREWALL)   text="Phase 4: Firewall configuration" ;;

    ko:PHASE_VERIFY)     text="Phase 5: 설치 검증" ;;
    en:PHASE_VERIFY)     text="Phase 5: Post-install verification" ;;

    # ── validate.sh ─────────────────────────────────────────
    ko:VAL_BOT_TOKEN_MISSING)
      text="SLACK_BOT_TOKEN이 설정되지 않았습니다. --slack-bot-token 또는 환경 변수로 제공하세요." ;;
    en:VAL_BOT_TOKEN_MISSING)
      text="SLACK_BOT_TOKEN is not set. Provide it via --slack-bot-token or env var." ;;

    ko:VAL_BOT_TOKEN_INVALID)
      text="SLACK_BOT_TOKEN 형식이 올바르지 않습니다. (예: xoxb-123456789...)" ;;
    en:VAL_BOT_TOKEN_INVALID)
      text="SLACK_BOT_TOKEN format is invalid. (e.g. xoxb-123456789...)" ;;

    ko:VAL_APP_TOKEN_MISSING)
      text="SLACK_APP_TOKEN이 설정되지 않았습니다. --slack-app-token 또는 환경 변수로 제공하세요." ;;
    en:VAL_APP_TOKEN_MISSING)
      text="SLACK_APP_TOKEN is not set. Provide it via --slack-app-token or env var." ;;

    ko:VAL_APP_TOKEN_INVALID)
      text="SLACK_APP_TOKEN 형식이 올바르지 않습니다. (예: xapp-1-A123...)" ;;
    en:VAL_APP_TOKEN_INVALID)
      text="SLACK_APP_TOKEN format is invalid. (e.g. xapp-1-A123...)" ;;

    ko:VAL_ANTHROPIC_KEY_MISSING)
      text="ANTHROPIC_API_KEY가 설정되지 않았습니다. --anthropic-api-key 또는 환경 변수로 제공하세요." ;;
    en:VAL_ANTHROPIC_KEY_MISSING)
      text="ANTHROPIC_API_KEY is not set. Provide it via --anthropic-api-key or env var." ;;

    ko:VAL_ANTHROPIC_KEY_INVALID)
      text="ANTHROPIC_API_KEY 형식이 올바르지 않습니다. (예: sk-ant-api03-...)" ;;
    en:VAL_ANTHROPIC_KEY_INVALID)
      text="ANTHROPIC_API_KEY format is invalid. (e.g. sk-ant-api03-...)" ;;

    ko:VAL_DEPS_MISSING)   text="다음 명령어가 설치되지 않았습니다: %s" ;;
    en:VAL_DEPS_MISSING)   text="The following commands are not installed: %s" ;;

    ko:VAL_DEPS_INSTALL_HINT)
      text="설치 방법: brew install %s  (macOS) 또는  apt install %s  (Ubuntu)" ;;
    en:VAL_DEPS_INSTALL_HINT)
      text="Install with: brew install %s  (macOS) or  apt install %s  (Ubuntu)" ;;

    ko:VAL_NODE_VERSION)   text="Node.js 18 이상이 필요합니다. 현재: v%s" ;;
    en:VAL_NODE_VERSION)   text="Node.js 18 or higher is required. Current: v%s" ;;

    ko:VAL_UFW_MISSING)
      text="ufw가 설치되지 않았습니다. 방화벽 설정을 건너뜁니다. (--skip-firewall로 경고 억제 가능)" ;;
    en:VAL_UFW_MISSING)
      text="ufw is not installed. Skipping firewall setup. (Use --skip-firewall to suppress this warning)" ;;

    ko:VAL_PORT_IN_USE)    text="포트 %s가 이미 사용 중입니다. (PID: %s, 프로세스: %s)" ;;
    en:VAL_PORT_IN_USE)    text="Port %s is already in use. (PID: %s, process: %s)" ;;

    ko:VAL_PORT_IN_USE_HINT)
      text="기존 OpenClaw 설치가 실행 중일 수 있습니다. --force 플래그를 사용하거나 uninstall.sh를 실행하세요." ;;
    en:VAL_PORT_IN_USE_HINT)
      text="An existing OpenClaw installation may be running. Use --force or run uninstall.sh." ;;

    ko:VAL_PORT_IN_USE_SIMPLE) text="포트 %s가 이미 사용 중입니다." ;;
    en:VAL_PORT_IN_USE_SIMPLE) text="Port %s is already in use." ;;

    ko:VAL_EXISTING_INSTALL_FORCE)
      text="기존 OpenClaw 설치가 감지되었습니다. --force 플래그로 인해 제거 후 재설치합니다." ;;
    en:VAL_EXISTING_INSTALL_FORCE)
      text="Existing OpenClaw installation detected. Removing and reinstalling due to --force flag." ;;

    ko:VAL_EXISTING_INSTALL)   text="기존 OpenClaw 설치가 감지되었습니다." ;;
    en:VAL_EXISTING_INSTALL)   text="Existing OpenClaw installation detected." ;;

    ko:VAL_EXISTING_INSTALL_HINT)
      text="재설치하려면 --force 플래그를 사용하거나 먼저 uninstall.sh를 실행하세요." ;;
    en:VAL_EXISTING_INSTALL_HINT)
      text="To reinstall, use --force or run uninstall.sh first." ;;

    ko:VAL_EXISTING_INSTALL_PATH) text="감지된 위치: %s" ;;
    en:VAL_EXISTING_INSTALL_PATH) text="Detected at: %s" ;;

    ko:VAL_FAIL_COUNT)     text="검증 실패: %s개의 오류가 발견되었습니다." ;;
    en:VAL_FAIL_COUNT)     text="Validation failed: %s error(s) found." ;;

    ko:VAL_DONE)           text="Phase 1 완료: 모든 검증 통과" ;;
    en:VAL_DONE)           text="Phase 1 complete: all validations passed" ;;

    # ── configure.sh ────────────────────────────────────────
    ko:CFG_GATEWAY_TOKEN_CREATED) text="게이트웨이 토큰 생성 완료" ;;
    en:CFG_GATEWAY_TOKEN_CREATED) text="Gateway token generated" ;;

    ko:CFG_ALLOW_FROM_JSON) text="allowFrom JSON: %s" ;;
    en:CFG_ALLOW_FROM_JSON) text="allowFrom JSON: %s" ;;

    ko:CFG_RENDERING)      text="템플릿 렌더링 중..." ;;
    en:CFG_RENDERING)      text="Rendering templates..." ;;

    ko:CFG_DRY_ENV)        text="[DRY-RUN] .env 파일 생성 예정: %s" ;;
    en:CFG_DRY_ENV)        text="[DRY-RUN] Will create .env file: %s" ;;

    ko:CFG_DRY_JSON)       text="[DRY-RUN] openclaw.json 파일 생성 예정: %s" ;;
    en:CFG_DRY_JSON)       text="[DRY-RUN] Will create openclaw.json: %s" ;;

    ko:CFG_DRY_MANIFEST)   text="[DRY-RUN] slack-manifest.yaml 파일 생성 예정: %s" ;;
    en:CFG_DRY_MANIFEST)   text="[DRY-RUN] Will create slack-manifest.yaml: %s" ;;

    ko:CFG_DRY_ALLOW_FROM) text="[DRY-RUN] OPENCLAW_ALLOW_FROM_JSON=%s" ;;
    en:CFG_DRY_ALLOW_FROM) text="[DRY-RUN] OPENCLAW_ALLOW_FROM_JSON=%s" ;;

    ko:CFG_ENV_CREATED)    text=".env 파일 생성: %s (chmod 600)" ;;
    en:CFG_ENV_CREATED)    text=".env file created: %s (chmod 600)" ;;

    ko:CFG_JSON_CREATED)   text="openclaw.json 생성: %s (chmod 600)" ;;
    en:CFG_JSON_CREATED)   text="openclaw.json created: %s (chmod 600)" ;;

    ko:CFG_JSON_INVALID)   text="생성된 openclaw.json이 유효하지 않습니다." ;;
    en:CFG_JSON_INVALID)   text="Generated openclaw.json is invalid." ;;

    ko:CFG_FILE_CONTENT)   text="파일 내용:" ;;
    en:CFG_FILE_CONTENT)   text="File contents:" ;;

    ko:CFG_JSON_VALID)     text="openclaw.json JSON 유효성 검증 통과" ;;
    en:CFG_JSON_VALID)     text="openclaw.json JSON validation passed" ;;

    ko:CFG_MANIFEST_CREATED) text="slack-manifest.yaml 생성: %s" ;;
    en:CFG_MANIFEST_CREATED) text="slack-manifest.yaml created: %s" ;;

    ko:CFG_RENDER_FAIL)    text="설정 파일 렌더링 실패" ;;
    en:CFG_RENDER_FAIL)    text="Failed to render configuration files" ;;

    ko:CFG_DONE)           text="Phase 2 완료: 설정 파일 생성됨 → %s" ;;
    en:CFG_DONE)           text="Phase 2 complete: configuration files created → %s" ;;

    ko:CFG_DONE_DRY)       text="Phase 2 완료 (dry-run)" ;;
    en:CFG_DONE_DRY)       text="Phase 2 complete (dry-run)" ;;

    # ── install.sh ──────────────────────────────────────────
    ko:INST_INSTALLING)    text="openclaw 패키지 설치 중..." ;;
    en:INST_INSTALLING)    text="Installing openclaw package..." ;;

    ko:INST_DRY_NPM)       text="[DRY-RUN] npm install -g openclaw@latest" ;;
    en:INST_DRY_NPM)       text="[DRY-RUN] npm install -g openclaw@latest" ;;

    ko:INST_NPM_FAIL)      text="npm install -g openclaw@latest 실패" ;;
    en:INST_NPM_FAIL)      text="npm install -g openclaw@latest failed" ;;

    ko:INST_CMD_NOT_FOUND)
      text="openclaw 명령어를 찾을 수 없습니다. npm global bin 경로를 확인하세요." ;;
    en:INST_CMD_NOT_FOUND)
      text="openclaw command not found. Check your npm global bin path." ;;

    ko:INST_NPM_BIN)       text="npm bin 경로: %s" ;;
    en:INST_NPM_BIN)       text="npm bin path: %s" ;;

    ko:INST_PATH)          text="PATH: %s" ;;
    en:INST_PATH)          text="PATH: %s" ;;

    ko:INST_DONE)          text="openclaw 설치 완료 (버전: %s)" ;;
    en:INST_DONE)          text="openclaw installed successfully (version: %s)" ;;

    ko:INST_ONBOARD_START) text="openclaw onboard 실행 중..." ;;
    en:INST_ONBOARD_START) text="Running openclaw onboard..." ;;

    ko:INST_DRY_CONFIG)    text="[DRY-RUN] OPENCLAW_CONFIG_PATH=%s/openclaw.json" ;;
    en:INST_DRY_CONFIG)    text="[DRY-RUN] OPENCLAW_CONFIG_PATH=%s/openclaw.json" ;;

    ko:INST_DRY_ONBOARD)
      text="[DRY-RUN] timeout 120 openclaw onboard --non-interactive --skip-health --gateway-bind lan --install-daemon" ;;
    en:INST_DRY_ONBOARD)
      text="[DRY-RUN] timeout 120 openclaw onboard --non-interactive --skip-health --gateway-bind lan --install-daemon" ;;

    ko:INST_ENV_LOADED)    text=".env 파일 로드 완료" ;;
    en:INST_ENV_LOADED)    text=".env file loaded" ;;

    ko:INST_ONBOARD_WAIT)  text="onboard 시작 (최대 120초 대기)..." ;;
    en:INST_ONBOARD_WAIT)  text="Starting onboard (waiting up to 120 seconds)..." ;;

    ko:INST_ONBOARD_SKIP_HEALTH)
      text="알려진 WebSocket 헬스체크 hang 버그(GitHub #7976) 우회를 위해 --skip-health 사용" ;;
    en:INST_ONBOARD_SKIP_HEALTH)
      text="Using --skip-health to bypass known WebSocket health check hang bug (GitHub #7976)" ;;

    ko:INST_ONBOARD_TIMEOUT)
      text="openclaw onboard가 120초 내에 완료되지 않았습니다 (타임아웃)" ;;
    en:INST_ONBOARD_TIMEOUT)
      text="openclaw onboard did not complete within 120 seconds (timeout)" ;;

    ko:INST_LOG_HINT)      text="로그 확인: journalctl -u openclaw 또는 %s/openclaw.log" ;;
    en:INST_LOG_HINT)      text="Check logs: journalctl -u openclaw or %s/openclaw.log" ;;

    ko:INST_ONBOARD_FAIL)  text="openclaw onboard 실패 (종료 코드: %s)" ;;
    en:INST_ONBOARD_FAIL)  text="openclaw onboard failed (exit code: %s)" ;;

    ko:INST_ONBOARD_DONE)  text="openclaw onboard 완료" ;;
    en:INST_ONBOARD_DONE)  text="openclaw onboard completed" ;;

    ko:INST_FORCE_REMOVE)  text="기존 설치 제거 중 (--force)..." ;;
    en:INST_FORCE_REMOVE)  text="Removing existing installation (--force)..." ;;

    ko:INST_DONE_PHASE)    text="Phase 3 완료: OpenClaw 설치 및 초기화 완료" ;;
    en:INST_DONE_PHASE)    text="Phase 3 complete: OpenClaw installed and initialized" ;;

    # ── firewall.sh ─────────────────────────────────────────
    ko:FW_SKIP)            text="방화벽 설정 건너뜀 (--skip-firewall)" ;;
    en:FW_SKIP)            text="Skipping firewall setup (--skip-firewall)" ;;

    ko:FW_UFW_NOT_FOUND)   text="ufw를 찾을 수 없습니다. 방화벽 설정을 건너뜁니다." ;;
    en:FW_UFW_NOT_FOUND)   text="ufw not found. Skipping firewall setup." ;;

    ko:FW_MANUAL_BLOCK)
      text="포트 %s를 수동으로 차단하세요 (iptables 또는 보안 그룹 설정)." ;;
    en:FW_MANUAL_BLOCK)
      text="Manually block port %s (iptables or security group settings)." ;;

    ko:FW_SUDO_NEEDED)
      text="ufw 설정에 root 권한이 필요합니다. sudo를 사용합니다." ;;
    en:FW_SUDO_NEEDED)
      text="Root privileges required for ufw setup. Using sudo." ;;

    ko:FW_BLOCKING)        text="포트 %s 외부 접근 차단 중..." ;;
    en:FW_BLOCKING)        text="Blocking external access to port %s..." ;;

    ko:FW_RULE_FAIL)       text="ufw 규칙 추가 실패. 수동으로 포트 %s를 차단하세요." ;;
    en:FW_RULE_FAIL)       text="Failed to add ufw rule. Manually block port %s." ;;

    ko:FW_ENABLE_FAIL)     text="ufw 활성화 실패." ;;
    en:FW_ENABLE_FAIL)     text="Failed to enable ufw." ;;

    ko:FW_DONE)            text="UFW 규칙 적용 완료: 외부에서 포트 %s 차단" ;;
    en:FW_DONE)            text="UFW rules applied: port %s blocked from external access" ;;

    ko:FW_STATUS)          text="UFW 상태:" ;;
    en:FW_STATUS)          text="UFW status:" ;;

    ko:FW_PROBLEM)         text="방화벽 설정에 문제가 있었습니다. 계속 진행합니다." ;;
    en:FW_PROBLEM)         text="Firewall setup encountered issues. Continuing." ;;

    ko:FW_GATEWAY_SECURE)
      text="게이트웨이는 127.0.0.1로만 바인딩되어 있어 기본 보안은 유지됩니다." ;;
    en:FW_GATEWAY_SECURE)
      text="Gateway is bound to 127.0.0.1 only, so basic security is maintained." ;;

    ko:FW_DONE_PHASE)      text="Phase 4 완료: 방화벽 설정 완료" ;;
    en:FW_DONE_PHASE)      text="Phase 4 complete: firewall configured" ;;

    # ── verify.sh ───────────────────────────────────────────
    ko:VFY_PROCESS_CHECK)  text="  [1/4] 프로세스 체크..." ;;
    en:VFY_PROCESS_CHECK)  text="  [1/4] Process check..." ;;

    ko:VFY_PROCESS_OK)     text="  [1/4] openclaw 프로세스 실행 중 (PID: %s)" ;;
    en:VFY_PROCESS_OK)     text="  [1/4] openclaw process is running (PID: %s)" ;;

    ko:VFY_PROCESS_NOT_FOUND) text="  [1/4] openclaw 프로세스를 찾을 수 없습니다." ;;
    en:VFY_PROCESS_NOT_FOUND) text="  [1/4] openclaw process not found." ;;

    ko:VFY_PROCESS_MANUAL) text="        수동 확인: pgrep -f openclaw" ;;
    en:VFY_PROCESS_MANUAL) text="        Manual check: pgrep -f openclaw" ;;

    ko:VFY_GATEWAY_CHECK)
      text="  [2/4] 게이트웨이 HTTP 응답 체크 (최대 30초)..." ;;
    en:VFY_GATEWAY_CHECK)
      text="  [2/4] Gateway HTTP response check (up to 30 seconds)..." ;;

    ko:VFY_GATEWAY_OK)     text="  [2/4] 게이트웨이 응답 확인 (시도 %s/%s)" ;;
    en:VFY_GATEWAY_OK)     text="  [2/4] Gateway responded (attempt %s/%s)" ;;

    ko:VFY_GATEWAY_RESPONSE) text="        응답: %s" ;;
    en:VFY_GATEWAY_RESPONSE) text="        Response: %s" ;;

    ko:VFY_GATEWAY_WAITING) text="  [2/4] 대기 중... (%s/%s)" ;;
    en:VFY_GATEWAY_WAITING) text="  [2/4] Waiting... (%s/%s)" ;;

    ko:VFY_GATEWAY_TIMEOUT)
      text="  [2/4] 게이트웨이가 30초 내에 응답하지 않았습니다." ;;
    en:VFY_GATEWAY_TIMEOUT)
      text="  [2/4] Gateway did not respond within 30 seconds." ;;

    ko:VFY_GATEWAY_URL)    text="        URL: %s" ;;
    en:VFY_GATEWAY_URL)    text="        URL: %s" ;;

    ko:VFY_GATEWAY_MANUAL) text="        수동 확인: curl %s" ;;
    en:VFY_GATEWAY_MANUAL) text="        Manual check: curl %s" ;;

    ko:VFY_SLACK_CHECK)    text="  [3/4] Slack 소켓 모드 연결 확인..." ;;
    en:VFY_SLACK_CHECK)    text="  [3/4] Slack Socket Mode connection check..." ;;

    ko:VFY_SLACK_OK_SYSTEMD)
      text="  [3/4] Slack 소켓 모드 연결 확인 (systemd 로그)" ;;
    en:VFY_SLACK_OK_SYSTEMD)
      text="  [3/4] Slack Socket Mode connection confirmed (systemd log)" ;;

    ko:VFY_SLACK_OK_LAUNCHD)
      text="  [3/4] Slack 소켓 모드 연결 확인 (launchd 로그)" ;;
    en:VFY_SLACK_OK_LAUNCHD)
      text="  [3/4] Slack Socket Mode connection confirmed (launchd log)" ;;

    ko:VFY_SLACK_OK_FILE)  text="  [3/4] Slack 소켓 모드 연결 확인 (%s)" ;;
    en:VFY_SLACK_OK_FILE)  text="  [3/4] Slack Socket Mode connection confirmed (%s)" ;;

    ko:VFY_SLACK_NOT_FOUND)
      text="  [3/4] Slack 소켓 모드 연결 로그를 확인하지 못했습니다." ;;
    en:VFY_SLACK_NOT_FOUND)
      text="  [3/4] Could not verify Slack Socket Mode connection from logs." ;;

    ko:VFY_SLACK_WAIT)     text="        연결이 완료되기까지 시간이 필요할 수 있습니다." ;;
    en:VFY_SLACK_WAIT)     text="        Connection may still be establishing." ;;

    ko:VFY_SLACK_MANUAL)   text="        수동 확인: journalctl -u openclaw -f" ;;
    en:VFY_SLACK_MANUAL)   text="        Manual check: journalctl -u openclaw -f" ;;

    ko:VFY_PORT_CHECK)     text="  [4/4] 포트 격리 보안 확인..." ;;
    en:VFY_PORT_CHECK)     text="  [4/4] Port isolation security check..." ;;

    ko:VFY_PORT_EXPOSED)   text="  [4/4] 포트 %s가 외부 인터페이스에 바인드되어 있습니다!" ;;
    en:VFY_PORT_EXPOSED)   text="  [4/4] Port %s is bound to an external interface!" ;;

    ko:VFY_PORT_EXPOSED_RISK)
      text="        보안 위험: 외부에서 게이트웨이에 직접 접근 가능" ;;
    en:VFY_PORT_EXPOSED_RISK)
      text="        Security risk: gateway is directly accessible from external networks" ;;

    ko:VFY_PORT_BINDINGS)  text="        바인딩 현황:" ;;
    en:VFY_PORT_BINDINGS)  text="        Bindings:" ;;

    ko:VFY_PORT_NO_TOOL)
      text="  [4/4] ss/lsof를 찾을 수 없어 포트 격리를 확인할 수 없습니다." ;;
    en:VFY_PORT_NO_TOOL)
      text="  [4/4] ss/lsof not found, cannot verify port isolation." ;;

    ko:VFY_UFW_RULE_NOT_FOUND)
      text="  [4/4] UFW에서 포트 %s 차단 규칙을 확인할 수 없습니다." ;;
    en:VFY_UFW_RULE_NOT_FOUND)
      text="  [4/4] Cannot verify UFW block rule for port %s." ;;

    ko:VFY_PORT_OK)
      text="  [4/4] 포트 격리 확인 완료 (127.0.0.1 전용 바인딩)" ;;
    en:VFY_PORT_OK)
      text="  [4/4] Port isolation verified (bound to 127.0.0.1 only)" ;;

    ko:VFY_SKIP)           text="검증 단계 건너뜀 (--skip-verify)" ;;
    en:VFY_SKIP)           text="Skipping verification (--skip-verify)" ;;

    ko:VFY_DRY_SKIP)       text="[DRY-RUN] 검증 단계 건너뜀" ;;
    en:VFY_DRY_SKIP)       text="[DRY-RUN] Skipping verification" ;;

    ko:VFY_DONE)           text="Phase 5 완료: 모든 검증 통과 (4/4)" ;;
    en:VFY_DONE)           text="Phase 5 complete: all checks passed (4/4)" ;;

    ko:VFY_WARN)           text="Phase 5 완료: 일부 검증 경고 (%s/4 실패)" ;;
    en:VFY_WARN)           text="Phase 5 complete: some checks with warnings (%s/4 failed)" ;;

    ko:VFY_WARN_INFO)      text="경고가 있지만 기본 기능은 동작할 수 있습니다." ;;
    en:VFY_WARN_INFO)      text="There are warnings but basic functionality may still work." ;;

    ko:VFY_FAIL)           text="Phase 5 실패: %s/4 검증 실패" ;;
    en:VFY_FAIL)           text="Phase 5 failed: %s/4 checks failed" ;;

    ko:VFY_FAIL_INFO)      text="설치에 문제가 있습니다. 로그를 확인하세요." ;;
    en:VFY_FAIL_INFO)      text="Installation has issues. Check the logs." ;;

    # ── provision.sh 배너 / 완료 ────────────────────────────
    ko:PROV_DRY_RUN_MODE)  text="  ⚠  DRY-RUN 모드: 실제 변경 없음" ;;
    en:PROV_DRY_RUN_MODE)  text="  ⚠  DRY-RUN mode: no actual changes" ;;

    ko:PROV_BOT_NAME)      text="  봇 이름:       %s" ;;
    en:PROV_BOT_NAME)      text="  Bot name:      %s" ;;

    ko:PROV_PRIMARY_MODEL) text="  기본 모델:     %s" ;;
    en:PROV_PRIMARY_MODEL) text="  Primary model: %s" ;;

    ko:PROV_STATE_DIR)     text="  상태 디렉터리: %s" ;;
    en:PROV_STATE_DIR)     text="  State dir:     %s" ;;

    ko:PROV_ALLOW_USERS)   text="  허용 사용자:   %s" ;;
    en:PROV_ALLOW_USERS)   text="  Allowed users: %s" ;;

    ko:PROV_ALLOW_USERS_NONE) text="  허용 사용자:   (없음 — 페어링 필요)" ;;
    en:PROV_ALLOW_USERS_NONE) text="  Allowed users: (none — pairing required)" ;;

    ko:PROV_UNKNOWN_OPTION) text="알 수 없는 옵션: %s" ;;
    en:PROV_UNKNOWN_OPTION) text="Unknown option: %s" ;;

    ko:PROV_SCRIPT_NOT_FOUND) text="스크립트 파일을 찾을 수 없습니다: %s" ;;
    en:PROV_SCRIPT_NOT_FOUND) text="Script file not found: %s" ;;

    ko:PROV_ABORT_VALIDATE)   text="프로비저닝 중단: 검증 실패" ;;
    en:PROV_ABORT_VALIDATE)   text="Provisioning aborted: validation failed" ;;

    ko:PROV_ABORT_CONFIGURE)  text="프로비저닝 중단: 설정 파일 렌더링 실패" ;;
    en:PROV_ABORT_CONFIGURE)  text="Provisioning aborted: configuration rendering failed" ;;

    ko:PROV_ABORT_INSTALL)    text="프로비저닝 중단: 설치 실패" ;;
    en:PROV_ABORT_INSTALL)    text="Provisioning aborted: installation failed" ;;

    ko:PROV_WARN_VERIFY)      text="프로비저닝 완료되었으나 일부 검증 실패" ;;
    en:PROV_WARN_VERIFY)      text="Provisioning complete but some verifications failed" ;;

    ko:PROV_INFO_CHECK_LOGS)  text="로그를 확인하고 수동으로 상태를 점검하세요." ;;
    en:PROV_INFO_CHECK_LOGS)  text="Check the logs and verify the status manually." ;;

    ko:PROV_SUCCESS_BANNER)   text="     OpenClaw 프로비저닝 완료!" ;;
    en:PROV_SUCCESS_BANNER)   text="     OpenClaw Provisioning Complete!" ;;

    ko:PROV_SUCCESS_CONNECTED)
      text="OpenClaw이 Slack과 소켓 모드로 연결되었습니다." ;;
    en:PROV_SUCCESS_CONNECTED)
      text="OpenClaw is connected to Slack in Socket Mode." ;;

    ko:PROV_SUCCESS_GATEWAY)
      text="게이트웨이: http://127.0.0.1:18789 (로컬 전용)" ;;
    en:PROV_SUCCESS_GATEWAY)
      text="Gateway: http://127.0.0.1:18789 (local only)" ;;

    ko:PROV_SUCCESS_CONFIG)   text="설정 파일: %s/openclaw.json" ;;
    en:PROV_SUCCESS_CONFIG)   text="Config file: %s/openclaw.json" ;;

    ko:PROV_NEXT_STEPS)       text="  다음 단계:" ;;
    en:PROV_NEXT_STEPS)       text="  Next steps:" ;;

    ko:PROV_NEXT_DM)          text="  1. Slack에서 @%s에게 DM을 보내 테스트하세요." ;;
    en:PROV_NEXT_DM)          text="  1. Send a DM to @%s in Slack to test." ;;

    ko:PROV_NEXT_PAIRING)
      text="  2. 첫 사용자는 페어링 코드로 인증이 필요합니다." ;;
    en:PROV_NEXT_PAIRING)
      text="  2. First-time users need to authenticate with a pairing code." ;;

    ko:PROV_NEXT_ALLOWED)     text="  2. 허용된 사용자(%s)는 바로 사용 가능합니다." ;;
    en:PROV_NEXT_ALLOWED)     text="  2. Allowed users (%s) can use it immediately." ;;

    ko:PROV_NEXT_UNINSTALL)   text="  3. 완전 제거: ./uninstall.sh" ;;
    en:PROV_NEXT_UNINSTALL)   text="  3. Complete removal: ./uninstall.sh" ;;

    ko:PROV_USEFUL_CMDS)      text="  유용한 명령어:" ;;
    en:PROV_USEFUL_CMDS)      text="  Useful commands:" ;;

    ko:PROV_CMD_STATUS)
      text="  • 상태 확인:  curl http://127.0.0.1:18789/api/status" ;;
    en:PROV_CMD_STATUS)
      text="  • Status check:  curl http://127.0.0.1:18789/api/status" ;;

    ko:PROV_CMD_LOG_LINUX)
      text="  • 로그 확인:  journalctl -u openclaw -f  (Linux)" ;;
    en:PROV_CMD_LOG_LINUX)
      text="  • View logs:  journalctl -u openclaw -f  (Linux)" ;;

    ko:PROV_CMD_LOG_MACOS)
      text="              cat %s/Library/Logs/openclaw/  (macOS)" ;;
    en:PROV_CMD_LOG_MACOS)
      text="              cat %s/Library/Logs/openclaw/  (macOS)" ;;

    # ── provision.sh usage ──────────────────────────────────
    ko:PROV_USAGE_HEADER)     text="사용법:" ;;
    en:PROV_USAGE_HEADER)     text="Usage:" ;;

    ko:PROV_USAGE_OPTIONS_LABEL) text="옵션" ;;
    en:PROV_USAGE_OPTIONS_LABEL) text="options" ;;

    ko:PROV_USAGE_REQUIRED)   text="필수 옵션:" ;;
    en:PROV_USAGE_REQUIRED)   text="Required options:" ;;

    ko:PROV_USAGE_OPTIONAL)   text="선택 옵션:" ;;
    en:PROV_USAGE_OPTIONAL)   text="Optional options:" ;;

    ko:PROV_USAGE_ENV)        text="환경 변수:" ;;
    en:PROV_USAGE_ENV)        text="Environment variables:" ;;

    ko:PROV_USAGE_ENV_DESC)
      text="모든 옵션은 동일한 이름의 환경 변수로 대체 가능합니다." ;;
    en:PROV_USAGE_ENV_DESC)
      text="All options can be set via environment variables with the same name." ;;

    ko:PROV_USAGE_ENV_EXAMPLE)  text="  예: SLACK_BOT_TOKEN=xoxb-... ./provision.sh" ;;
    en:PROV_USAGE_ENV_EXAMPLE)  text="  e.g. SLACK_BOT_TOKEN=xoxb-... ./provision.sh" ;;

    ko:PROV_USAGE_EXAMPLES)     text="예시:" ;;
    en:PROV_USAGE_EXAMPLES)     text="Examples:" ;;

    ko:PROV_USAGE_BASIC_INSTALL) text="# 기본 설치" ;;
    en:PROV_USAGE_BASIC_INSTALL) text="# Basic installation" ;;

    ko:PROV_USAGE_ALLOW_USER)    text="# 특정 사용자 허용 + dry-run" ;;
    en:PROV_USAGE_ALLOW_USER)    text="# Pre-approve specific users + dry-run" ;;

    ko:PROV_OPT_ALLOW_FROM_DESC)
      text="허용할 Slack Member ID (여러 번 사용 가능)" ;;
    en:PROV_OPT_ALLOW_FROM_DESC)
      text="Allowed Slack Member ID (can be specified multiple times)" ;;

    ko:PROV_OPT_MODEL_DESC)
      text="기본 AI 모델 (기본값: anthropic/claude-opus-4-6)" ;;
    en:PROV_OPT_MODEL_DESC)
      text="Primary AI model (default: anthropic/claude-opus-4-6)" ;;

    ko:PROV_OPT_BOT_NAME_DESC)   text="봇 이름 (기본값: OpenClaw)" ;;
    en:PROV_OPT_BOT_NAME_DESC)   text="Bot display name (default: OpenClaw)" ;;

    ko:PROV_OPT_STATE_DIR_DESC)  text="설정 저장 경로 (기본값: ~/.openclaw)" ;;
    en:PROV_OPT_STATE_DIR_DESC)  text="State storage path (default: ~/.openclaw)" ;;

    ko:PROV_OPT_SKIP_FW_DESC)    text="UFW 설정 건너뜀" ;;
    en:PROV_OPT_SKIP_FW_DESC)    text="Skip UFW setup" ;;

    ko:PROV_OPT_SKIP_VERIFY_DESC) text="검증 단계 건너뜀" ;;
    en:PROV_OPT_SKIP_VERIFY_DESC) text="Skip verification phase" ;;

    ko:PROV_OPT_FORCE_DESC)      text="기존 설치 제거 후 재설치" ;;
    en:PROV_OPT_FORCE_DESC)      text="Remove existing installation and reinstall" ;;

    ko:PROV_OPT_DRY_RUN_DESC)    text="실제 실행 없이 출력만" ;;
    en:PROV_OPT_DRY_RUN_DESC)    text="Show output without making changes" ;;

    ko:PROV_OPT_VERBOSE_DESC)    text="상세 로그 출력" ;;
    en:PROV_OPT_VERBOSE_DESC)    text="Enable verbose logging" ;;

    ko:PROV_OPT_HELP_DESC)       text="도움말 표시" ;;
    en:PROV_OPT_HELP_DESC)       text="Show this help message" ;;

    ko:PROV_OPT_LANG_DESC)
      text="출력 언어 설정 (기본값: 시스템 LANG 자동 감지)" ;;
    en:PROV_OPT_LANG_DESC)
      text="Set output language (default: auto-detected from system LANG)" ;;

    # ── uninstall.sh ────────────────────────────────────────
    ko:UNINST_USAGE)
      text="사용법: ./uninstall.sh [--yes] [--state-dir PATH] [--skip-firewall] [--lang ko|en]" ;;
    en:UNINST_USAGE)
      text="Usage: ./uninstall.sh [--yes] [--state-dir PATH] [--skip-firewall] [--lang ko|en]" ;;

    ko:UNINST_OPT_YES)           text="확인 프롬프트 없이 실행" ;;
    en:UNINST_OPT_YES)           text="Run without confirmation prompt" ;;

    ko:UNINST_OPT_STATE_DIR)     text="삭제할 상태 디렉터리 (기본값: ~/.openclaw)" ;;
    en:UNINST_OPT_STATE_DIR)     text="State directory to delete (default: ~/.openclaw)" ;;

    ko:UNINST_OPT_SKIP_FIREWALL) text="UFW 규칙 제거 건너뜀" ;;
    en:UNINST_OPT_SKIP_FIREWALL) text="Skip UFW rule removal" ;;

    ko:UNINST_OPT_LANG)
      text="출력 언어 설정 (기본값: 시스템 LANG 자동 감지)" ;;
    en:UNINST_OPT_LANG)
      text="Set output language (default: auto-detected from system LANG)" ;;

    ko:UNINST_UNKNOWN_OPT)       text="알 수 없는 옵션: %s" ;;
    en:UNINST_UNKNOWN_OPT)       text="Unknown option: %s" ;;

    ko:UNINST_BANNER_TITLE)      text="OpenClaw 완전 제거 (Uninstall)" ;;
    en:UNINST_BANNER_TITLE)      text="OpenClaw Complete Uninstall" ;;

    ko:UNINST_BANNER_WARN)       text="이 작업은 되돌릴 수 없습니다." ;;
    en:UNINST_BANNER_WARN)       text="This action cannot be undone." ;;

    ko:UNINST_TARGETS)           text="  제거 대상:" ;;
    en:UNINST_TARGETS)           text="  Will remove:" ;;

    ko:UNINST_TARGET_PROCESS)    text="  • openclaw 프로세스 종료" ;;
    en:UNINST_TARGET_PROCESS)    text="  • Stop openclaw processes" ;;

    ko:UNINST_TARGET_NPM)        text="  • openclaw npm 패키지 제거" ;;
    en:UNINST_TARGET_NPM)        text="  • Remove openclaw npm package" ;;

    ko:UNINST_TARGET_STATE_DIR)  text="  • 상태 디렉터리: %s" ;;
    en:UNINST_TARGET_STATE_DIR)  text="  • State directory: %s" ;;

    ko:UNINST_TARGET_RELATED_DIRS) text="  • 관련 디렉터리: %s-*" ;;
    en:UNINST_TARGET_RELATED_DIRS) text="  • Related directories: %s-*" ;;

    ko:UNINST_TARGET_UFW)        text="  • UFW 포트 18789 규칙 제거" ;;
    en:UNINST_TARGET_UFW)        text="  • Remove UFW port 18789 rule" ;;

    ko:UNINST_CONFIRM_WARN)
      text="경고: 이 작업은 모든 OpenClaw 데이터를 영구적으로 삭제합니다." ;;
    en:UNINST_CONFIRM_WARN)
      text="Warning: This will permanently delete all OpenClaw data." ;;

    ko:UNINST_CONFIRM_PROMPT)    text="계속하시겠습니까? [y/N] " ;;
    en:UNINST_CONFIRM_PROMPT)    text="Continue? [y/N] " ;;

    ko:UNINST_CANCELLED)         text="취소되었습니다." ;;
    en:UNINST_CANCELLED)         text="Cancelled." ;;

    ko:UNINST_STEP1)             text="1/6 openclaw 게이트웨이 정지 중..." ;;
    en:UNINST_STEP1)             text="1/6 Stopping openclaw gateway..." ;;

    ko:UNINST_STEP1_OK)          text="게이트웨이 정지 명령 전송" ;;
    en:UNINST_STEP1_OK)          text="Gateway stop command sent" ;;

    ko:UNINST_CMD_NOT_FOUND)     text="openclaw 명령어를 찾을 수 없습니다. 건너뜁니다." ;;
    en:UNINST_CMD_NOT_FOUND)     text="openclaw command not found. Skipping." ;;

    ko:UNINST_STEP2)             text="2/6 openclaw 데몬 제거 중..." ;;
    en:UNINST_STEP2)             text="2/6 Removing openclaw daemon..." ;;

    ko:UNINST_STEP2_OK)          text="openclaw 데몬 제거 완료" ;;
    en:UNINST_STEP2_OK)          text="openclaw daemon removed" ;;

    ko:UNINST_LAUNCHD_REMOVED)   text="launchd 서비스 제거: %s" ;;
    en:UNINST_LAUNCHD_REMOVED)   text="launchd service removed: %s" ;;

    ko:UNINST_STEP3)             text="3/6 openclaw 프로세스 강제 종료 중..." ;;
    en:UNINST_STEP3)             text="3/6 Force-killing openclaw processes..." ;;

    ko:UNINST_STEP3_OK)          text="openclaw 프로세스 종료 완료" ;;
    en:UNINST_STEP3_OK)          text="openclaw processes terminated" ;;

    ko:UNINST_NO_PROCESS)        text="실행 중인 openclaw 프로세스 없음" ;;
    en:UNINST_NO_PROCESS)        text="No running openclaw processes found" ;;

    ko:UNINST_STEP4)             text="4/6 상태 디렉터리 삭제 중..." ;;
    en:UNINST_STEP4)             text="4/6 Deleting state directories..." ;;

    ko:UNINST_DELETED)           text="삭제: %s" ;;
    en:UNINST_DELETED)           text="Deleted: %s" ;;

    ko:UNINST_DIR_NOT_FOUND)     text="%s 디렉터리 없음" ;;
    en:UNINST_DIR_NOT_FOUND)     text="%s directory not found" ;;

    ko:UNINST_STEP5)             text="5/6 openclaw npm 패키지 제거 중..." ;;
    en:UNINST_STEP5)             text="5/6 Removing openclaw npm package..." ;;

    ko:UNINST_STEP5_OK)          text="npm 패키지 제거 완료" ;;
    en:UNINST_STEP5_OK)          text="npm package removed" ;;

    ko:UNINST_NPM_NOT_INSTALLED) text="openclaw npm 패키지가 설치되지 않음" ;;
    en:UNINST_NPM_NOT_INSTALLED) text="openclaw npm package is not installed" ;;

    ko:UNINST_STEP6)             text="6/6 UFW 방화벽 규칙 제거 중..." ;;
    en:UNINST_STEP6)             text="6/6 Removing UFW firewall rules..." ;;

    ko:UNINST_STEP6_OK)          text="UFW 포트 18789 규칙 제거 완료" ;;
    en:UNINST_STEP6_OK)          text="UFW port 18789 rule removed" ;;

    ko:UNINST_UFW_NO_RULE)       text="UFW에서 포트 18789 관련 규칙 없음" ;;
    en:UNINST_UFW_NO_RULE)       text="No UFW rules found for port 18789" ;;

    ko:UNINST_UFW_NOT_FOUND)     text="ufw를 찾을 수 없습니다. 방화벽 규칙 제거 건너뜀." ;;
    en:UNINST_UFW_NOT_FOUND)     text="ufw not found. Skipping firewall rule removal." ;;

    ko:UNINST_STEP6_SKIP)        text="6/6 방화벽 규칙 제거 건너뜀 (--skip-firewall)" ;;
    en:UNINST_STEP6_SKIP)        text="6/6 Skipping firewall rule removal (--skip-firewall)" ;;

    ko:UNINST_DONE_BANNER)       text="     OpenClaw 제거 완료" ;;
    en:UNINST_DONE_BANNER)       text="     OpenClaw Uninstalled" ;;

    ko:UNINST_DONE_MSG)          text="  OpenClaw이 완전히 제거되었습니다." ;;
    en:UNINST_DONE_MSG)          text="  OpenClaw has been completely removed." ;;

    ko:UNINST_DONE_REINSTALL)    text="  재설치하려면 ./provision.sh를 다시 실행하세요." ;;
    en:UNINST_DONE_REINSTALL)    text="  To reinstall, run ./provision.sh again." ;;

    # ── fallback ────────────────────────────────────────────
    *)
      text="[missing: ${key}]" ;;
  esac

  if [[ $# -gt 0 ]]; then
    # shellcheck disable=SC2059
    printf "${text}" "$@"
  else
    echo "${text}"
  fi
}

export -f msg
