# OpenClaw + Slack 자동 프로비저닝

OpenClaw AI 에이전트를 Slack에 Socket Mode로 자동 연결하는 **Zero-touch Provisioning** 도구입니다.
운영자가 CLI 한 번만 실행하면 설치, 설정, 보안, 검증까지 모두 자동으로 완료됩니다.

---

## 빠른 시작

```bash
./provision.sh \
  --slack-bot-token  xoxb-... \
  --slack-app-token  xapp-... \
  --anthropic-api-key sk-ant-...
```

---

## 디렉터리 구조

```
openclaw_slack/
├── provision.sh                      # 메인 진입점 (5-Phase 오케스트레이터)
├── uninstall.sh                      # 완전 초기화 (재난 복구)
├── templates/
│   ├── env.template                  # .env 파일 템플릿
│   ├── openclaw.json.template        # OpenClaw 설정 JSON 템플릿
│   └── slack-manifest.yaml.template  # Slack App Manifest 템플릿 (참고용)
└── scripts/
    ├── validate.sh                   # Phase 1: 입력 검증 + 의존성 체크
    ├── configure.sh                  # Phase 2: 템플릿 렌더링 (envsubst)
    ├── install.sh                    # Phase 3: npm install + openclaw onboard
    ├── firewall.sh                   # Phase 4: UFW 방화벽 규칙
    └── verify.sh                     # Phase 5: 설치 후 헬스체크
```

---

## CLI 옵션

| 옵션 | 필수 | 설명 |
|------|------|------|
| `--slack-bot-token TOKEN` | ✅ | Slack Bot Token (`xoxb-...`) |
| `--slack-app-token TOKEN` | ✅ | Slack App-Level Token (`xapp-...`, Socket Mode용) |
| `--anthropic-api-key KEY` | ✅ | Anthropic API Key (`sk-ant-...`) |
| `--allow-from USER_ID` | — | 허용할 Slack Member ID (여러 번 사용 가능) |
| `--primary-model MODEL` | — | 기본 AI 모델 (기본값: `anthropic/claude-opus-4-6`) |
| `--bot-name NAME` | — | 봇 표시 이름 (기본값: `OpenClaw`) |
| `--state-dir PATH` | — | 설정 저장 경로 (기본값: `~/.openclaw`) |
| `--skip-firewall` | — | UFW 설정 건너뜀 |
| `--skip-verify` | — | 검증 단계 건너뜀 |
| `--force` | — | 기존 설치 제거 후 재설치 |
| `--dry-run` | — | 실제 실행 없이 출력만 확인 |
| `--verbose` / `-v` | — | 상세 로그 출력 |

모든 옵션은 동일한 이름의 **환경 변수**로도 설정 가능합니다 (CI/CD secrets 주입 시 활용).

---

## 실행 단계 (5-Phase)

### Phase 1: validate.sh — 입력 검증
- 토큰 형식 정규식 검증
  - `SLACK_BOT_TOKEN`: `^xoxb-[0-9A-Za-z-]+$`
  - `SLACK_APP_TOKEN`: `^xapp-[0-9A-Za-z-]+$`
  - `ANTHROPIC_API_KEY`: `^sk-ant-[a-zA-Z0-9_-]+$`
- 의존성 체크: `node`(≥18), `npm`, `openssl`, `envsubst`, `curl`
- 포트 18789 사용 여부 확인
- 기존 OpenClaw 설치 감지 (`--force` 없으면 경고 후 종료)

### Phase 2: configure.sh — 설정 파일 생성
- `OPENCLAW_GATEWAY_TOKEN` 자동 생성 (`openssl rand -hex 32`)
- `--allow-from` 인자들을 JSON 배열로 변환
- `envsubst`로 3개 파일 렌더링:
  - `~/.openclaw/.env` (chmod 600)
  - `~/.openclaw/openclaw.json` (chmod 600)
  - `~/.openclaw/slack-manifest.yaml` (참고용)
- `node -e "JSON.parse(...)"` 로 JSON 유효성 검증

### Phase 3: install.sh — OpenClaw 설치
```bash
npm install -g openclaw@latest
timeout 120 openclaw onboard \
  --non-interactive \
  --skip-health \      # GitHub #7976 알려진 hang 버그 우회
  --gateway-bind lan \
  --install-daemon     # systemd/launchd 데몬 자동 등록
```

### Phase 4: firewall.sh — 방화벽 설정
```bash
ufw deny in on any to any port 18789 proto tcp
ufw --force enable
```
- `--skip-firewall` 시 또는 `ufw` 미설치 환경에서는 경고만 출력

### Phase 5: verify.sh — 설치 후 헬스체크 (4-Layer)
| 레이어 | 검증 항목 |
|--------|----------|
| 1/4 | 프로세스 체크: `pgrep -f openclaw` |
| 2/4 | 게이트웨이 HTTP 응답: `curl http://127.0.0.1:18789/api/status` (30초 폴링) |
| 3/4 | Slack 연결: 로그에서 "socket mode connected" 패턴 탐지 |
| 4/4 | 포트 격리: 포트 18789가 외부 인터페이스에 바인드되지 않음 확인 |

---

## 사용 예시

### 기본 설치
```bash
./provision.sh \
  --slack-bot-token xoxb-123456789-abcdefghij \
  --slack-app-token xapp-1-A1B2C3D4E5-abc123 \
  --anthropic-api-key sk-ant-api03-xxxx
```

### 특정 사용자 사전 허용 (Strategy A)
```bash
./provision.sh \
  --slack-bot-token xoxb-... \
  --slack-app-token xapp-... \
  --anthropic-api-key sk-ant-... \
  --allow-from U12345678 \
  --allow-from U87654321
```
허용된 사용자는 페어링 코드 없이 즉시 봇을 사용할 수 있습니다.

### Dry-run (실제 실행 없이 확인)
```bash
./provision.sh \
  --slack-bot-token xoxb-... \
  --slack-app-token xapp-... \
  --anthropic-api-key sk-ant-... \
  --dry-run --verbose
```

### CI/CD 환경 (환경 변수 주입)
```bash
export SLACK_BOT_TOKEN="xoxb-..."
export SLACK_APP_TOKEN="xapp-..."
export ANTHROPIC_API_KEY="sk-ant-..."
./provision.sh --skip-firewall
```

### 재설치 (기존 설치 덮어쓰기)
```bash
./provision.sh \
  --slack-bot-token xoxb-... \
  --slack-app-token xapp-... \
  --anthropic-api-key sk-ant-... \
  --force
```

---

## 완전 제거

```bash
./uninstall.sh
```

확인 없이 즉시 제거:
```bash
./uninstall.sh --yes
```

제거 범위:
- openclaw 게이트웨이 및 데몬 중지
- npm 패키지 제거
- `~/.openclaw`, `~/.openclaw-*` 디렉터리 삭제
- UFW 포트 18789 규칙 제거
- systemd / launchd 서비스 제거

---

## 보안 설계

| 항목 | 구현 |
|------|------|
| 게이트웨이 바인딩 | `127.0.0.1` 전용 — 외부 직접 접근 불가 |
| 게이트웨이 토큰 | `openssl rand -hex 32` 자동 생성 |
| 설정 파일 권한 | `.env`, `openclaw.json` → `chmod 600` |
| 방화벽 (이중 방어) | UFW로 포트 18789 외부 차단 |
| 샌드박스 | 비-주 세션은 `sandbox.mode: "non-main"` 격리 |
| 도구 제한 | `allowlist`: bash, read, write, edit / `denylist`: browser, canvas, gateway 등 |

---

## 주요 설계 결정

| 결정 | 이유 |
|------|------|
| `envsubst` 템플릿 엔진 | 외부 의존성 없음, 토큰 특수문자 안전 처리 |
| 서브스크립트 `source` 방식 | 변수가 모든 Phase에 공유 (서브셸 불필요) |
| `--skip-health` 항상 포함 | GitHub #7976 알려진 hang 버그 우회 |
| `timeout 120 openclaw onboard` | 새 인터랙티브 프롬프트 추가 시 CI 무한 대기 방지 |
| `OPENCLAW_CONFIG_PATH` export | onboard가 pre-rendered 설정 파일 읽도록 강제 |
| `dmPolicy: "pairing"` 유지 | 미등록 사용자는 페어링 필요 (belt-and-suspenders) |

---

## 사전 요구사항

- **OS**: Linux (systemd) 또는 macOS (launchd)
- **Node.js**: v18 이상
- **npm**: 최신 버전
- **의존성**: `openssl`, `envsubst`, `curl`
- **선택**: `ufw` (방화벽 설정 시)

---

## 참고 문서

- [OpenClaw GitHub](https://github.com/openclaw/openclaw)
- [Slack App Manifest 문서](https://docs.slack.dev/app-manifests/)
