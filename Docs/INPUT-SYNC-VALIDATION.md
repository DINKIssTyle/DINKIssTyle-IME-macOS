# 입력 전환 개선 및 검증 기록

2026-10-14. 기준 커밋 `f02cb08` 이후 작업.

## 변경 사항

- 활성화 직후, DKST가 클라이언트를 조회하기 전에 100ms 응답 제한을 설정한다. 해당 비공개 API를 지원하지 않거나 호출이 실패해도 처리를 계속한다. IMK 상위 클래스의 활성화는 기존 순서대로 먼저 호출한다.
- 초기화 과정의 진단용 Bundle ID 조회를 제거했다.
- 성공한 활성화 뒤에는 키보드 override를 반복하지 않는다. override가 예외로 실패한 경우에만 다음 키 처리 전에 한 번 재시도한다. 실패가 계속되어도 매 키마다 반복하지 않는다. 새로운 클라이언트를 감지한 경우에는 그 프록시에 응답 제한과 레이아웃을 적용한다. Safari/WebKit의 eager override 회피 정책은 유지한다.
- 활성화마다 수행하던 설정/한자 단축키 재조회를 제거했다. 최초 로드한 설정을 사용하고, 변경 알림이 오면 다음 조합 경계에서 갱신한다. 일반 설정에도 프로세스 간 변경 알림을 추가했다. 조합 중 direct/marked 방식과 삭제 동작을 바꾸지 않는다. modifier-only 단축키 변경은 일반 키 입력 없이도 적용한다.
- Release에서 진단용 `markedRange`와 삽입 직후의 진단용 `selectedRange` 조회를 제외했다. 조합 정확성 검증과 필요한 커서 상태 저장은 유지했다.
- 일시적인 direct 입력 실패로 marked 방식에 들어간 경우에만 새 조합에서 정책을 다시 평가한다. 영구 marked 정책의 불필요한 재조회는 하지 않는다. 런타임 정책 조회에서 예외가 발생하면 기존 Bundle ID/범위 정책으로 대체한다.
- 사전 변경 관찰을 singleton 사전으로 이동했다. 입력 세션 수만큼 중복 파싱하지 않으며, 같은 run-loop에 도착한 연속 갱신 요청을 합친다.
- 사전 후보의 표시 문자열과 삽입 문자열을 별도로 보관한다. 공백 포함 문구/이모티콘을 보존하고 Apple 후보 설명과 기존 로컬 `값 (설명)` 형식을 처리한다. 사전을 갱신해도 이미 표시한 후보의 삽입 값은 유지한다. 원문 유지 후보가 다른 표시 문자열과 같아도 원문을 보존한다. 닫힌 후보창의 늦은 콜백은 무시한다.

## 자동 검증

```sh
bash Sources_Tester/run-tests.sh
DKST_TEST_MODE=debug bash Sources_Tester/run-tests.sh
```

기본 모드는 제품 Release와 같은 `-O2 -DNDEBUG`, Debug는 `-O0 -DDEBUG`다. 테스트 assertion은 유지된다.

검증 대상:

- 기존 direct 입력/자동 완성/줄바꿈/선택 변경/복구/후보 선택의 회귀 시나리오.
- 활성화 응답 제한 설정 순서, 최초 두 키 조합, 20회 연속 재활성화와 첫 음절 입력.
- 성공 경로의 override 중복 방지, 실패 시 한 번 재시도, 반복 실패의 호출 횟수 제한, 활성화 콜백 없이 클라이언트가 바뀌는 경우, WebKit 예외 유지.
- 조합 도중 설정 변경 보류, 변경 알림 병합, 새 조합에서 정책 반영, modifier-only 단축키 갱신, 비공개 API 예외.
- Release에서 진단용 marked 범위 조회가 발생하지 않는지 확인.
- 공백 포함 후보/이모티콘, 중첩 설명, Apple 삽입 값, 사전 갱신 중 열린 후보 목록, 원문 유지 후보의 표시 충돌, 반복된 늦은 콜백.
- 사전 갱신 요청 병합.

개선 전 컨트롤러/정책 소스에 새 활성화 검사를 적용하면 `client read preceded reply timeout setup`으로 실패한다. 개선 후 통과한다. 수신한 키가 올바르게 처리되는지를 검증하는 모의 테스트이며, 시스템의 입력 소스 전환이나 앱의 실제 XPC 지연을 재현한 통합 테스트는 아니다.

검증 결과: Release 및 Debug 각각 Objective-C 실행 파일 8개와 Python 테스트 8개 통과. 진단을 활성화한 Release 활성화 검사도 통과했다. 전체 앱과 내장 설정 앱은 `x86_64`/`arm64` Universal Release로 빌드하고 ad-hoc 코드 서명을 검증했다. 빌드 도구의 Simulator 서비스 경고가 있었으나 macOS용 NIB 컴파일과 전체 빌드는 성공했다.

## 실사용 계측

기본값에서는 상세 계측을 실행하지 않는다. 설치된 입력기를 검증용 빌드로 교체한 뒤 다음 설정을 켜고 입력기를 다시 실행해야 한다.

```sh
defaults write com.dinkisstyle.inputmethod.DKST DKSTTraceInput -bool true
```

계측 설정은 프로세스에서 한 번만 읽는다. 매 키마다 설정이나 클라이언트 정보를 추가 조회하지 않는다. 터미널에서 실행하는 검증 프로세스에는 `DKST_TRACE_INPUT=1` 환경 변수도 사용할 수 있다.

로그 보기:

```sh
log stream --style compact --predicate 'subsystem == "com.dinkisstyle.inputmethod.DKST" AND category == "InputSync"'
```

최근 기록 보기:

```sh
log show --last 10m --style compact --predicate 'subsystem == "com.dinkisstyle.inputmethod.DKST" AND category == "InputSync"'
```

로그에는 활성화 세대, 컨트롤러/클라이언트 식별값, 이벤트 종류/키코드/수정키, 처리 여부와 경과 시간을 남긴다. 문서 내용이나 조합 문자열을 조회하여 기록하지 않는다.

| 관측 | 다음 조사 |
| --- | --- |
| DKST 표시 뒤 `activate-begin` 자체가 없음 | 시스템 입력 소스와 해당 앱 입력 컨텍스트의 불일치 |
| `activate-begin` 후 `activate-end`가 늦음 | 활성화 또는 레이아웃/정책 조회 대기; `keyboard-sync-*` 시점 비교 |
| 활성화 완료 후 영어를 입력했지만 `event-begin`이 없음 | 이벤트가 DKST에 전달되지 않는 입력 세션/클라이언트 경로 |
| 이벤트가 오지만 `handled=0` | 키코드, modifier, 단축키/통과 분기 |
| `handled=1`과 `marked-output`/`direct-output` 뒤에도 로마자가 남음 | 호스트의 원문 키 처리 또는 IMK 출력 적용 순서 |
| `keyboard-sync-failed`, `direct-output-failed`, `event-exception` | 프록시 연결/응답/출력 실패 |

`elapsed_ms`는 해당 처리 구간의 시간이다. `event_age_ms`는 수신 이벤트의 timestamp로부터 경과한 시간이며, 외부에서 관측한 한영 전환 키 시점과 같은 지표는 아니다. 컨트롤러 내부 처리 시간과 전달되기 전의 대기를 구분해 해석한다.

TextEdit, Safari, Chromium/Electron 및 실제 문제 앱에서 다음을 비교한다.

1. 전환 직후 `r`/`k`에 해당하는 두 키로 `가` 입력.
2. 빠른 한영 왕복 전환, 앱/필드 이동 직후 입력.
3. CPU 부하가 있는 상태와 저사양 머신에서 같은 입력.
4. 입력기 표시는 바뀌었으나 영어가 계속 입력되는 순간의 이벤트 수신 여부.
5. 기존 체크리스트의 Messages Shift+Return, Calendar/Excel 자동 완성, 선택 삭제, 한자 키보드 선택.

종료 후 계측을 끄고 입력기를 다시 실행한다.

```sh
defaults delete com.dinkisstyle.inputmethod.DKST DKSTTraceInput
```

## 현재 완료 범위

코드 개선, 모의 회귀 검사, Universal 앱 빌드 및 서명 검증 후 사용자 승인에 따라 시스템 입력기를 교체했다. 저사양 머신 및 사용자가 실제로 문제를 경험한 앱에서의 해결 여부는 별도 확인이 필요하다.

### 설치 후 확인 (2026-10-14)

- 설치 위치: `/Library/Input Methods/DKST.app`.
- 기존 설치본 백업: `Notes/Backups/DKST-sync-20261014/DKST.app`. 백업은 Git에서 제외된다.
- 기존 설치본의 arm64 코드 서명 검사는 `invalid signature (code or signature have been modified)`로 실패했다. 원본과 백업 실행 파일의 SHA-256은 일치한다. 이 사실만으로 로마자 누출의 원인을 확정하지 않는다.
- 교체한 설치본은 전체 코드 서명 검사를 통과했고, 검증 빌드와 SHA-256이 일치한다: `b4c01a940329fb75a044650b1615b9341cee71465fa83dc5245f2f89d54e12f0`.
- 기존 사용자 DKST 프로세스에는 SIGTERM을 전달했다. SIGKILL은 사용하지 않았다. 이후 새 DKST 프로세스의 활성화와 실제 키 처리 로그를 확인했다.
- 이 Mac은 macOS 27.2이며 입력 소스 전환 단축키는 Command+Space로 설정되어 있다.
- NSTextField에서 한영 왕복 10회와 전환 직후 `rk` 입력 결과가 `rk 가` 10회와 일치했다.
- 기존 테스터의 실제 키 이벤트 자동 입력으로 NSTextField, NSSearchField, NSComboBox, NSTokenField, Logging/Plain NSTextView, WKWebView 7종에서 `rk` → `가`를 확인했다.
- 자동화 도구의 직접 키 입력은 일부 NSTextView에서 IME를 거치지 않는 결과를 보였다. 이를 제품의 로마자 누출 재현으로 판정하지 않고, 테스터의 실제 키 이벤트 결과와 구분했다.

### 전환 경계 반복 테스트 도구

`Sources_Tester/IMETester.m`에 `매 문구 영문→DKST 전환` 옵션과 전환 후 대기시간(ms)을 추가했다. 활성 입력 컨텍스트의 공개 `selectedKeyboardInputSource` 속성으로 영문 소스를 선택하고 50ms 뒤 DKST를 선택한 다음 설정된 대기시간 후 키를 입력한다. 0ms는 DKST 선택 요청 뒤 명시적인 대기를 넣지 않는 경우다. 시스템 전환 단축키의 내부 구현과 같은 경로라고 가정하지 않는다. [Apple API 문서](https://developer.apple.com/documentation/appkit/nstextinputcontext/selectedkeyboardinputsource)

테스터가 포커스를 잃으면 다른 앱에 키를 보내지 않도록 중단한다. WebKit 비동기 결과 검사가 끝나기 전에 다음 반복을 시작하던 문제도 수정했고, 반복 사이의 로그를 유지하며 불일치 수를 집계한다.

설치 후 이 옵션을 켜고 대기시간 0ms, 문구 `rk, dkssudgktpdy`, 반복 3회로 검증했다. 7종 입력창 × 문구 2개 × 3회 = 42번의 영문→DKST 전환 후 입력을 수행했으며, 21개 컨트롤별 결과가 모두 `가 안녕하세요`와 일치했다. 테스터의 최종 집계는 `3 pass(es), 0 failed result(s)`였다. 첫 시도는 테스트 창이 비활성 상태여서 포커스 보호 로직에 따라 입력 전에 중단됐고, 창을 앞으로 가져온 뒤 전체 검증을 완료했다.

상세 계측은 검증 중에만 켰고, 릴리즈 전 사용자 요청으로 `DKSTTraceInput=false`로 끈 뒤 기존 입력기 프로세스에 SIGTERM을 전달해 캐시된 진단 설정을 해제했다. 릴리즈의 기본값도 꺼짐이다. 간헐적인 실사용 증상이 다시 발생하면 필요할 때 계측을 다시 켜 조사할 수 있다. 이 결과는 이 Mac의 공개 입력 컨텍스트 API를 이용한 전환 테스트이며, 저사양 머신이나 시스템 전환 단축키의 모든 경합 상황이 해결되었다는 보장은 아니다.

이번 로그 수집 구간(23:27:28–23:40:20, 한국 시간)에서 입력기 예외/레이아웃 동기화 실패/직접 삽입 실패는 관찰되지 않았다. 활성화 84건의 처리 시간은 중앙값 2.363ms, P95 11.671ms, 최대 15.481ms였다. modifier 없는 `r`/`k` 이벤트 130건의 DKST 내부 처리 시간은 중앙값 1.583ms, P95 3.483ms, 최대 24.911ms였다. 이 구간에는 테스트 이외의 앱 포커스 이동도 포함된다. 전환 단축키 입력부터 화면 표시까지의 전체 지연이나 개선 전 대비 속도 향상 수치로 해석하지 않는다.
