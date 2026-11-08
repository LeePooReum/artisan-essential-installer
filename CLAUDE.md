# 필수 프로그램 설치 도구 (by Artisan) — 인수인계 문서

윈도우 포맷 직후 자주 쓰는 프로그램 44개를 체크해서 한 번에 설치하는 GUI 도구입니다. winget 기반이고, 결과물은 EXE 파일 하나입니다.
현재 배포 이름은 `필수프로그램설치도구_v2.0_정식판.exe`(버전 2.0.0, 2026-11-08)입니다. 사용자용 안내는 `읽어주세요.txt`(사용 방법 + 버전별 변경점)에 있고 EXE와 함께 배포합니다. 원래 작성자가 직접 만든 V2(WinForms + C 런처)에서 시작해 지금 구조로 재작성했습니다.

---

## 0. 작업 원칙 (사용자 요청 사항)

- **경어체(존댓말)로 답변합니다.** 반말은 쓰지 않습니다.
- 사용자가 **"빌드해"** 라고 하면 EXE를 다시 빌드해서 넘깁니다. 파일 이름은 `필수프로그램설치도구_v2.0_정식판.exe`를 유지합니다(버전을 올리면 이름의 vX.Y도 함께 바꾸고 `읽어주세요.txt`에 변경점 추가).
- 사용자는 결과를 **실제 Windows에서 테스트하고 로그(`install_log.txt`)나 화면 캡처로 피드백**합니다. 추측으로 고치지 말고 로그의 종료코드와 실제 PC 상태(설치 폴더, 레지스트리, 로그 파일)로 원인을 확인한 뒤 고쳐 주세요. 이전 작업에서 검증 없이 "고쳤다"고 넘긴 것이 반복 실패의 가장 큰 원인이었습니다.
- 확인하지 못한 것은 확인하지 못했다고 분명히 말합니다.
- 아이콘은 반드시 **실제 프로그램 아이콘**이어야 합니다. 임의로 만든 비슷한 아이콘은 안 됩니다(카카오톡 아이콘을 잘못 넣었다가 지적받은 적이 있습니다).
- 관리자 권한(UAC) 요청은 **실행 시 한 번만** 떠야 합니다.

---

## 1. 파일 구조

| 파일 | 설명 |
|---|---|
| `installer.ps1` | **본체.** PowerShell 5.1 + WPF(XAML) GUI, 앱 목록, 설치 감지, 설치 엔진 전부 (약 1,300줄) |
| `icons/*.png` | 앱 아이콘 44개 (64px, 파일명 = 앱의 `Id`, Store 앱은 Store ID) + `_artisan.png`(ArtisanOS 'A' 브랜드 로고, 128px). 빌드 시 스크립트에 base64로 내장 |
| `Fonts/` | Pretendard Medium/Bold/Light (.otf, SIL OFL — `Fonts/LICENSE.txt`). ArtisanOS와 같은 파일. 빌드 시 EXE에 관리형 리소스로 내장 |
| `docs/legacy/app-download-arrow.ico` | 2026-11-08 이전 EXE 아이콘(파란 다운로드 화살표). 지금 `app.ico`는 ArtisanOS의 `artisan.ico` |
| `Launcher.cs` | .NET Framework 4.x 런처. EXE 안의 스크립트를 **임시 파일 없이 같은 프로세스 안에서** PowerShell 엔진으로 실행 |
| `app.manifest` | `requireAdministrator` (UAC 한 번) |
| `app.ico` | EXE 아이콘 (7개 해상도) |
| `launcher.rc` | 리눅스 빌드용 Win32 리소스 정의 (아이콘 + 매니페스트) |
| `build.sh` | 리눅스 빌드 (mono `mcs` + mingw `windres` + python3) |
| `build.ps1` | **Windows 빌드** (기본 내장 `csc.exe`). Windows PC에서 작업한다면 이것을 쓰세요 |
| `docs/gemini/` | 2026-11-08 이전 UI의 원본(Gemini XAML 3개). **지금 UI는 ArtisanOS 디자인으로 교체됨.** 참고용, 빌드에 쓰지 않음(이 원본에도 `<Setter.Value>` 누락 오류가 있음) |

`script.build.ps1`과 `*.exe`는 빌드 산출물입니다.

---

## 2. 빌드

### Windows (권장: 실제로 실행·테스트까지 가능)
```powershell
powershell -ExecutionPolicy Bypass -File .\build.ps1
# 또는 이름 지정
powershell -ExecutionPolicy Bypass -File .\build.ps1 -Out "필수프로그램설치도구_v2.0_정식판.exe"
```
- 아이콘 내장 → PowerShell 문법 검사 → `csc.exe`(`%WINDIR%\Microsoft.NET\Framework64\v4.0.30319\`) 컴파일 순서로 진행합니다.
- `build.ps1`의 1~2단계는 리눅스 pwsh로 시험해 `build.sh`와 바이트 단위로 같은 `script.build.ps1`이 나오는 것을 확인했습니다. 2026-11-08 Windows 11(PowerShell 5.1)에서 3단계까지 성공했습니다.
- **`build.ps1`은 반드시 UTF-8 BOM으로 저장하세요.** BOM이 없으면 한국어 Windows의 PowerShell 5.1이 CP949로 읽어 한글이 깨지고 문법 오류로 빌드가 실패합니다(리눅스 pwsh에서는 드러나지 않음).

### 리눅스
```bash
sudo apt-get install -y mono-devel gcc-mingw-w64-x86-64   # windres 가 gcc 전처리기를 씀
./build.sh "필수프로그램설치도구_v2.0_정식판.exe"
```

### 빌드 후 확인할 것
- PowerShell 문법 오류 0개 (`build.ps1`은 자동 검사합니다)
- 메인 창 XAML에 코드가 찾는 x:Name 16개가 모두 있는지 (5장 참고)
- 가능하면 **Windows에서 직접 실행**해서 창이 뜨는지, 설치 여부가 맞게 나오는지 확인

---

## 3. 실행 구조

1. **Launcher.cs**
   - 환경변수 `PI_SCRIPT_DIR`(EXE 폴더, 끝에 `\`)와 `PI_EXE_PATH`를 설정합니다.
   - 관리형 리소스 `script.ps1`을 읽고, `System.Management.Automation`(Windows 기본 PowerShell 5.1)을 **리플렉션으로** 불러옵니다.
   - Runspace를 STA + `UseCurrentThread`로 만들고 실행 정책은 이 프로세스 안에서만 `Bypass`로 둡니다.
   - 시작 단계 오류는 MessageBox로 `예외종류: 메시지`를 보여 줍니다.
   - 주의: `PowerShell.Invoke()`는 제네릭 버전 `Invoke<T>()`와 겹쳐 `GetMethod("Invoke", Type.EmptyTypes)`가 "모호한 일치"(AmbiguousMatchException)를 냅니다. 그래서 `GetMethods()`에서 제네릭이 아닌 것을 골라 씁니다. 이것이 V10이 실행되지 않았던 원인입니다.
2. **installer.ps1**
   - XAML로 창을 만들고 `$Categories`(앱 목록)로 왼쪽 카테고리 버튼과 목록 행을 생성합니다.
   - 아이콘은 다음 순서로 찾습니다: EXE 옆 `icons\` 폴더 → 내장 base64 → 설치된 프로그램에서 추출 → 이니셜 타일.
   - `ContentRendered`에서 설치 여부 확인과 winget 상태 확인을 시작합니다.
   - 200ms `DispatcherTimer` 하나로 winget 확인, 설치 진행 등 모든 비동기 처리를 폴링합니다. 별도 스레드는 없습니다.
   - 로그는 화면과 EXE 폴더의 `install_log.txt`에 남습니다.

### 왜 .NET 런처인가 (V9 → V10)
원래 C 런처는 "임시 폴더에 .ps1을 떨어뜨리고 숨은 `powershell.exe -ExecutionPolicy Bypass`로 실행"하는 방식이었습니다. 이 동작이 드로퍼 악성코드와 같아서 백신 ML 엔진이 오진했습니다(VirusTotal 7/71, 시그니처 엔진은 모두 정상). 그래서 같은 프로세스 안에서 실행하는 방식으로 바꿨지만, **사용자 보고로는 VirusTotal 결과가 바뀌지 않았습니다.** 원인은 서명 없는 신규 EXE, 관리자 권한, 설치 동작 자체로 추정합니다. 사용자는 C#/WPF 네이티브 재작성 대신 현재 구조를 유지하기로 결정했습니다.

---

## 4. 앱 목록 (`$Categories`, installer.ps1 상단)

카테고리 순서: 브라우저(9) · 메신저&협업(4) · 동영상 플레이어(2) · 음악 플레이어(7) · 뷰어(3) · 압축 프로그램(3) · 유틸리티(5) · 게임런처(3) · AI Tool(3) · 개발(5) = 44개

2026-11-08 추가 9개:
| 앱 | Id | 설치 방법 | 근거 |
|---|---|---|---|
| Comet | `Perplexity.Comet` | 직접 설치 `--install --silent` (실패 시 winget) | winget 목록 주소가 "항상 최신" → 해시 불일치 위험. 무인 옵션은 winget-pkgs 목록 값 |
| Dia | `TheBrowserCompany.Dia` (가짜 Id) | DirectOnly, `DiaInstaller.exe --silent`, 설치 창 방식 | winget·Store 없음. `--silent`는 설치 파일 안 문자열에서 찾은 것(**미검증**) |
| 어사이드 | `AtYourSide.Aside` (가짜 Id) | DirectOnly + DirectPage(aside.com/download?os=win), 설치 창 방식 | winget·Store 없음. 주소에 버전이 박혀 있음 |
| 벅스 | `NHNBugs.Bugs` | 직접 설치 NSIS `/S` (실패 시 winget) | winget 목록 주소가 "항상 최신" |
| 멜론 | `KakaoEntertainmentCorp.MelonPlayer` | 직접 설치 NSIS `/S` (실패 시 winget) | 같음 |
| 지니뮤직 | `GenieMusic.GeniePlayer` (가짜 Id) | DirectOnly + DirectPage(genie.co.kr/guide/geniePC), 설치 창 방식 | winget·Store 없음. InstallShield(InstallScript)라 응답 파일 없이 무인 설치 불가 |
| 애플뮤직 | `9PFHDD62MXS1` (msstore) | Store | `Appx='^AppleInc\.AppleMusic'`(패키지 이름 **미확인**) |
| 파이썬 | `Python.Python.3.14` | winget | 버전 고정 주소. 3.15가 나오면 Id를 바꿔야 함 |
| 자바 (JDK) | `EclipseAdoptium.Temurin.25.JDK` | winget (MSI) | Java 25 LTS의 무료 OpenJDK 배포판. Oracle JDK 대신 Temurin을 고름 |

- 가짜 Id는 winget에 없는 앱의 아이콘 파일 이름·임시 파일 이름으로만 쓰입니다. 화면의 winget ID 칸에는 "공식 사이트 직접 설치"로 나옵니다.
- 6개 설치 파일(Comet·Dia·어사이드·벅스·멜론·지니)은 모두 제조사 Authenticode 서명이 "Valid"인 것을 확인했습니다(2026-11-08).
- 새 앱의 `Paths`·`Match`는 실제로 설치해 확인하지 않았습니다(Comet 경로는 Chromium 관례로 추정, 벅스·멜론·지니·Dia·어사이드는 게시자 + 이름 정규식만 사용). 실제 PC에서 설치 후 "설치됨"으로 바뀌는지 확인이 필요합니다.

아이콘 출처(모두 실제 프로그램/공식 배포처 이미지):
- Dia·멜론·지니: 공식 설치 파일의 실행 파일 아이콘(256px)
- Comet: Microsoft Store 목록(게시자 Perplexity AI)의 로고 / 애플뮤직: Microsoft Store 목록(게시자 Apple Inc.)의 로고
- 어사이드: aside.com `icon.png`(512px) / 벅스: music.bugs.co.kr 공식 파비콘(256px 프레임) / 파이썬: python.org apple-touch-icon / 자바: adoptium.net `adoptium-icon.png`
- Comet·어사이드·벅스의 **설치 파일 아이콘은 일반 "설치 상자" 그림이라 쓰지 않았습니다.**

| 필드 | 의미 |
|---|---|
| `Name` / `Id` | 표시 이름 / winget ID (Store 앱은 Store ID) |
| `Source` | `msstore`이면 Store 소스로 설치 (기본 `winget`) |
| `Match` | 설치 감지용 정규식. 레지스트리 Uninstall 키의 DisplayName에 맞춥니다 |
| `Publisher` | (선택) Match와 함께 확인할 게시자 정규식 |
| `Paths` | 설치 감지용 실제 파일·폴더 경로들 (`%ProgramFiles%` 등 환경변수 사용). **사용자 PC를 직접 조회해서 넣은 값** |
| `Appx` | Store/MSIX 패키지 이름 정규식 |
| `DirectUrl` / `DirectArgs` | winget 대신 제조사 공식 주소에서 직접 받아 설치 (`.msi`면 `msiexec /qn`, 아니면 exe + DirectArgs) |
| `DirectOnly` | winget에 없는 앱. 직접 설치가 실패해도 winget으로 넘어가지 않고 직접 설치로 재시도. 화면에 "공식 사이트 직접 설치" 표시 |
| `DirectPage` / `DirectPattern` | 설치할 때 공식 다운로드 페이지를 읽어 정규식으로 최신 설치 파일 주소를 찾음. 못 찾으면 `DirectUrl` 사용. **패턴에 따옴표(`'` `"`)를 쓰면 안 됨**(숨은 PowerShell 명령 문자열이 깨짐) |
| `Interactive` | 조용히 설치할 수 없음 → 설치 창을 띄움 (웨일 직접 설치, 블리자드) |
| `DefaultLocation` | `--location`이 꼭 필요한 패키지의 기본 경로 (블리자드: 0x8A15005F) |
| `IgnoreHash` | (예전 방식) 해시 검사 건너뛰기 표시. 효과가 없어 DirectUrl로 대체됨 |

직접 설치 대상: 크롬(기업용 MSI), 웨일(설치 창), 허니뷰(`/S`), AIMP(`/AUTO /SILENT`, `aimp.ru/?do=download.file&id=3` = 최신 64비트), 카카오톡(`/S`, `app-pc.kakaocdn.net/talk/win32/x64/KakaoTalk_Setup.exe`, 2026-11-08 추가).

---

## 5. UI (XAML)

- **2026-11-08부터 ArtisanOS와 같은 디자인**입니다(기준: `Artisan-Full-Handoff-20261105/desktop-current/source/ArtisanOS.ps1`의 메인 창 XAML).
  - 토큰: 바탕 `#F4F5F7`, 카드 `#FFFFFF`, 글자 `#1C1F26`, 보조 글자 `#5B6270`, 강조 `#2557D6`(호버 `#1E47B3`), 테두리 `#E3E6EB`
  - 글꼴: Pretendard(EXE 내장 → `%LOCALAPPDATA%\ArtisanOS\Fonts`에 풀어 씀, ArtisanOS와 같은 폴더). EXE 옆에 `Fonts\`가 있으면 그것을 먼저 씀. XAML에는 `__UIFONT__` 자리 표시자로 들어가고 `$UiFont`로 바뀝니다.
  - 기호: Segoe Fluent Icons(없으면 Segoe MDL2 Assets). 카테고리 기호는 `$CatGlyph`
  - 창: `WindowStyle=None` + `WindowChrome`(높이 44 제목 표시줄, 검색창이 제목 표시줄 안에 있음). 최대화하면 `RootGrid`에 7px 여백
  - EXE 아이콘·창 아이콘·로고: ArtisanOS 'A' 마크(`app.ico` = `artisan.ico`, 창 안 로고 = `icons/_artisan.png`)
- 메인 창 XAML은 `installer.ps1`의 `$XamlText = @' ... '@` 안에 있습니다. 카테고리 버튼(`New-NavButton`)과 목록 행(`New-Row`)은 **따로 Parse하는 조각**입니다.
  - 조각은 창과 따로 읽히므로 `StaticResource`를 쓰면 오류가 납니다. 반드시 `DynamicResource`를 쓰세요.
  - **`<Setter Property="Template">` 안에는 반드시 `<Setter.Value>`로 감싸서 넣으세요.** 빠지면 Windows에서 창이 안 뜹니다(2026-11-08 "안 열림" 원인).
  - 목록 머리글 열 너비(40/50/*/210/110)와 오른쪽 여백 35는 `New-Row`의 열 너비·안쪽 여백과 맞춘 값입니다. 목록 ScrollViewer는 스크롤바 자리를 항상 확보합니다(`Visible`).
- 코드가 `FindName`으로 찾는 이름(바꾸면 안 됨):
  - 메인 창: `NavPanel, WgDot, WgText, CatTitle, SearchBox, SearchHint, AllCheck, ListPanel, EmptyText, PathBox, PathHint, BrowseBtn, SelText, LogBtn, InstallBtn, InstallText` + `RootGrid, WinMin, WinMax, WinClose, BrandImg, BrandLogo`
  - 카테고리 버튼: `ind`(카테고리 기호, 선택 시 강조색), `nm`
  - 목록 행: `cb`, `tile`, `img`, `pill`, `st`
- 리소스 키: `AppBackground, ContentBackground, AccentColor, AccentHover, TextPrimary, TextSecondary, BorderColor, HoverColor, FocusRing, IconFont, ChromeBtn, ChromeClose, NavButton, FluentTextBox, SearchField, FluentCheck, StandardBtn, PrimaryBtn, RowStyle, Panel`
- 상태 배지 색(`$StatusStyles`)은 ArtisanOS 토큰을 씁니다: 성공 `#ECF7EF/#1E6B3A`, 진행 `#EAF0FC/#1E47B3`, 주의 `#FEF3E7/#B54708`, 오류 `#FDECEC/#B42318`, 중립 `#F0F1F4/#4A5160`.
- 사이드바 맨 아래: "커뮤니티 참여하기" 하이퍼링크(`CommunityLink`, Discord `https://discord.gg/EeR5bbF68A`)와 버전(`VerText`).
  - 버전 값은 `installer.ps1` 맨 위 `$AppVersion`(현재 2.0.0). 릴리스할 때 `Launcher.cs`의 `AssemblyVersion`/`AssemblyFileVersion`과 함께 올리세요. 로그의 "설치 시작" 줄에도 찍힙니다.
  - 링크는 `explorer.exe <주소>`로 엽니다. 이 도구는 관리자 권한이라 `Start-Process <주소>`로 열면 브라우저까지 관리자 권한이 되기 때문입니다(2026-11-08 클릭해서 Chrome에 열리는 것 확인).
- 카테고리 버튼 높이는 34(여백 포함 약 40)입니다. 11개 + winget 카드 + 링크 줄이 기본 창 높이(740)에서 스크롤 없이 들어가게 맞춘 값입니다.
- 카테고리 선택 표시는 `Set-Category`가 버튼의 Background/BorderBrush/Foreground를 바꿔서 합니다(호버는 템플릿 안 반투명 레이어라 서로 충돌하지 않음).

---

### 담은 항목 페이지 (2026-11-08)
- 목록에서 체크 → **'선택 항목 담기'**(AddCartBtn) → 사이드바 **'담은 항목'**(CartNav, 개수 배지) → **'순차 설치 시작'**(InstallBtn). 설치는 담은 항목에서만 시작합니다($script:Cart, 담은 순서).
- 담은 항목 화면(CartView): 위쪽 안내 카드(CartHead/CartInfo/CartProg: '순차 설치 중 · n / N 완료 · 지금: 이름'), 줄마다 순서·아이콘·이름·**진행 단계 문구**(Set-Stage)·상태 배지·빼기(✕). 상태 배지는 목록과 같이 바뀝니다(Set-Status가 둘 다 갱신, 경과 시간은 Set-PillText). 상태 'carted'(담김) 추가.
- 검색창에 입력하면 목록 화면으로 돌아갑니다. '목록 비우기'는 설치 중이 아닐 때만, 완료된 항목은 목록에서 '설치됨'으로 바뀝니다.

## 6. 설치 여부 감지 (`Test-InstalledFromRegistry`, `Test-AppRegistered`)

셋 중 하나라도 맞으면 "설치됨"으로 표시합니다. 설치된 항목은 체크박스가 비활성화되고 "전체 선택"에서도 빠집니다.
1. **레지스트리** `Uninstall` 키(HKLM/HKCU, 64/32비트)의 DisplayName을 `Match`로 확인
2. **`Paths`**: 실제 설치 파일이 있는지 확인. 한글 DisplayName(예: 팟플레이어 → "다음팟플레이어")이나 비표준 위치 때문에 1번이 놓치는 경우를 대비합니다
3. **`Appx`**: `HKCU\Software\Classes\Local Settings\Software\Microsoft\Windows\CurrentVersion\AppModel\Repository\Packages`의 패키지 이름을 직접 읽습니다
   - **`Get-AppxPackage`는 이 런처(같은 프로세스 안 PowerShell)에서 오류 없이 빈 결과를 냅니다.** Codex와 Claude가 설치되어 있어도 "미설치"로 보였던 원인입니다. 레지스트리를 기본으로 쓰고 Get-AppxPackage는 대체용으로만 둡니다.
   - 사용자 PC에서 확인한 패키지 이름: Claude=`Claude`, ChatGPT/Codex(Store 9PLM9XGG6VKS, Store 표시 이름 "ChatGPT")=`OpenAI.Codex`, PC Manager=`Microsoft.MicrosoftPCManager`, Quick Share=`NearbyShare`

### winget 상태 카드 (2026-11-08)
- 시작 시 `winget --version`(세 자리, 예: v1.29.380)을 읽고, 이어서 GitHub `microsoft/winget-cli`의 **최신 정식 릴리스**(`releases/latest`, 프리뷰 제외)와 비교합니다.
  - 같거나 높음: "최신 버전입니다"(초록) / 낮음: "새 버전(vX)이 있습니다"(주황) + "업데이트 (vX)" 버튼 / 확인 실패: "최신 버전을 확인하지 못했습니다"
  - winget 없음: "winget 설치하기" 버튼(같은 방법으로 새로 설치)
- 업데이트/설치: 숨은 `powershell.exe -EncodedCommand`에서 릴리스의 `Microsoft.DesktopAppInstaller_8wekyb3d8bbwe.msixbundle`(약 207MB)을 받아 `Add-AppxPackage -ForceApplicationShutdown`. 실패하면 `DesktopAppInstaller_Dependencies.zip`(약 93MB)의 x64/x86 구성 요소를 먼저 설치하고 다시 시도. 그래도 실패하면 Store '앱 설치 관리자'(9NBLGGH4NNS1) 페이지를 열지 묻습니다. Store를 거치지 않아 Store가 없는 PC에서도 동작하게 한 것입니다.
  - 업데이트 중에는 프로그램 설치를 막고, 설치 중에는 업데이트를 막습니다. 끝나면 버전을 다시 읽어 카드를 갱신합니다. 진행 내용은 `install_log.txt`에 `└` 줄로 남습니다.
  - **업데이트/설치 동작 자체는 실기 미검증**(이 PC가 이미 최신이라 실행하지 않았음). 화면 상태는 테스트용 환경변수 `PI_TEST_WG_VERSION=1.28.0`으로 확인했습니다.

winget export는 보조로만 씁니다. export 기반 판정은 불안정해서 "설치 여부 확인 실패"가 뜨던 문제가 있었습니다.

---

## 7. 설치 엔진 (`Start-AppInstall` → `Step-Install` → `Complete-Job`)

- 시작 전에 `winget source update`를 실행합니다(최대 30초).
- **순차 설치(한 번에 1개, `$script:MaxConcurrent = 1`, 2026-11-08 사용자 요청)**: 담은 순서대로 진행하고, 실패하면 그 자리에서 재시도·대체 다운로드까지 마친 뒤 다음 항목으로 넘어갑니다(`Fill-Slots`가 재시도 큐를 먼저 처리). 예전 동시 3개는 화면에서 진행을 따라가기 어려웠습니다.
- **Start-Process -Wait 금지(설치 프로그램 실행)**: Windows PowerShell의 `-Wait`는 설치 프로그램이 띄운 자식 프로세스(설치 끝에 실행된 앱)까지 기다립니다. 어사이드·지니뮤직이 20분 시간 초과로 끝난 원인이었고, `-PassThru` + `$p.Handle` + `$p.WaitForExit()`로 설치 프로그램 자신만 기다립니다(msiexec는 그대로).
- 한 작업이 **20분**을 넘으면 시간 초과로 처리합니다(`$script:JobTimeoutMin`).
- winget 명령: `winget install --id X -e --source <winget|msstore> --accept-package-agreements --accept-source-agreements --silent --force [--disable-interactivity] [--location ...]`
- 실패한 항목은 모든 설치가 끝난 뒤 **하나씩 한 번 재시도**합니다.
  - 해시 불일치였으면 `--ignore-security-hash`를 붙입니다. 실제로는 효과가 없었습니다(아래 참고).
  - 의존성 실패였으면 `--skip-dependencies`를 붙입니다.
  - 직접 설치가 종료코드 1(다운로드 오류)이면 winget으로 재시도합니다.
- **직접 설치**: 숨은 `powershell.exe -Command`에서 처리합니다(`ErrorActionPreference=Stop` + try/catch).
  - 다운로드는 `Invoke-WebRequest`로 하고, 실패하면 `curl.exe --ssl-no-revoke`로 다시 받습니다. 1MB 미만이면 실패로 봅니다.
  - MSI는 `Global\_MSIExecute` 뮤텍스가 풀릴 때까지 최대 10분 기다리고, 1618이면 30초 간격으로 최대 4회 재시도합니다.
  - 진행 내용(`downloaded N bytes`, `installer exit code N`, `ERROR: ...`)을 stdout으로 내보내 로그에 `└` 줄로 남깁니다.
  - **설치 프로그램 종료코드 0을 믿지 않습니다.** 끝난 뒤 6장의 감지로 실제 설치를 확인합니다(최대 45초, 설치 창 방식은 300초).
  - 과거 버그: 오류를 무시한 채 `exit $p.ExitCode`가 `$null`이 되어 실패가 "종료코드 0"으로 보였습니다.
- **인증서 신뢰 실패**(winget 0x80072F0D, curl 60, .NET "트러스트 관계")가 있으면, 끝난 뒤 사용자 동의를 받고 `certutil -generateSSTFromWU`로 받은 Microsoft 공식 루트 인증서 목록을 LocalMachine\Root에 추가합니다(`Update-RootCerts`).
- 완료 메시지는 타이머 처리 밖에서 `Dispatcher.BeginInvoke(ApplicationIdle)`로 띄웁니다. 끝난 뒤에도 "설치 중"으로 남은 줄이 있으면 "확인 필요"로 정리합니다.

### winget 실패 대응: 대체 다운로드 (2026-11-08, `Test-DownloadFailure` / `$FallbackTemplate` / `Complete-Job`)
- **사용자에게 "직접 받아 설치하라"고 넘기지 않습니다**(사용자 요청). 예전의 '공식 다운로드 페이지 열기'(`Show-FailedPages`)는 제거했습니다.
- 언제: winget 다운로드 오류(0x8A150008, 0x80072EE0~0x80072FA7, 0x80D0xxxx, 0x8019xxxx(404 제외))면 **바로**, 그 밖의 winget 실패는 **winget 재시도까지 실패하면** 대체 다운로드(앱마다 1번). msstore 앱과 '패키지 없음'(0x8A150014)은 제외. DirectUrl 앱은 직접 설치 → winget → 대체 다운로드 순.
- 어떻게(숨은 powershell, `-EncodedCommand`): `winget show`에서 설치 파일 URL·SHA256(URL 다음 줄)·종류(위쪽 줄 중 알려진 값. 사이에 '로캘' 줄이 끼는 앱이 있음)를 표시 언어와 무관하게 줄 모양으로 읽음 → **받기 3가지**(Invoke-WebRequest → curl.exe → BITS, 전부 실패하면 10초 뒤 한 번 더) → SHA256 일치 시 실행, 다르면 **Authenticode 서명 Valid일 때만** 실행(서명 없는 파일 거부, msix는 Windows가 검사).
- 무인 옵션: exe/nullsoft/inno/burn은 **winget 공식 매니페스트(raw.githubusercontent.com/microsoft/winget-pkgs/master/manifests/<첫 글자>/<Id 점→/>/<버전>/<Id>.installer.yaml)의 `Silent` 값**을 씀(해당 설치 파일 블록 → 루트 순). 없으면 종류별 기본값(nullsoft `/S`, inno `/VERYSILENT…`, burn `/quiet`), msi/wix `/qn`, msix `Add-AppxPackage`. 확인 결과 Opera `/silent`, AIMP `/AUTO /SILENT`, 반디뷰·반디집 `/S`, Acrobat `-sfx_nu /sAll /rs /msi`, Claude `--silent`, WinRAR `-s1` 등을 찾음. Brave·Discord는 값이 없음(원래 인자 없이 조용히 설치됨), Battle.net은 무인 설치 불가.
- SHA256은 .NET으로 계산합니다. **런처 안에서 띄운 powershell은 `Get-FileHash`를 못 찾았습니다**(실기에서 발견). 그래서 `Start-HiddenPs`가 `PSModulePath`를 시스템 기본값으로 바꿔서 띄웁니다.
- 화면: 담은 항목의 각 줄 아래에 단계 문구(`Set-Stage`). 예: "winget 다운로드 실패 (0x8A150008) → 도구가 공식 주소에서 직접 받아 설치하는 '대체 다운로드'로 바로 넘어갑니다" → "대체 다운로드로 설치 완료 (설치 확인됨)".
- winget **자체** 업데이트/설치: GitHub API를 못 읽으면 `https://aka.ms/getwinget`로 받고 curl.exe로도 시도. 끝내 실패하면 Store 페이지 안내(기존).
- **테스트용 환경변수**: `PI_TEST_WG_DLFAIL=1`(winget 설치를 0x8A150008로 실패 흉내), `PI_TEST_FB_BADURL=1`(대체 다운로드 주소를 없는 주소로), `PI_TEST_WG_NOAPI=1`(winget 업데이트 시 GitHub API 실패 흉내).
- **실기 검증(2026-11-08, 관리자 권한 배포 EXE)**: 흉내 모드로 foobar2000·7-Zip·Everything이 '다운로드 실패 → 대체 다운로드 → 설치 확인됨'으로 실제 설치됨. 미검증: 'winget 재시도 실패 → 대체 다운로드' 경로(다운로드 외 오류), BITS 경로, `aka.ms` 경로 winget 설치.
### 자주 나오는 종료코드
| 코드 | 의미 | 처리 |
|---|---|---|
| 0, 3010, 1641, 0x8A150109 | 성공 / 재부팅 필요 | 완료 |
| 0x8A150061, 0x8A15002B | 이미 설치됨 / 최신 | 완료 |
| 0x8A150011 (-1978335215) | **설치 파일 해시 불일치** (제조사가 "항상 최신" 주소를 쓰는데 winget 목록이 낡음) | DirectUrl로 해결해야 함 |
| 0x8A150014 | 패키지 없음 | 재시도 안 함 |
| 0x8A15005F (-1978335137) | 설치 위치 필요 | DefaultLocation |
| 0x8A150102 / 1618 | 다른 설치 진행 중 | 재시도, MSI는 대기 |
| 0x8A150110 (-1978334960) | 의존성(VC++ 런타임 등) 설치 실패 | `--skip-dependencies` 재시도 |
| 0x80190194 (-2145844844) | 다운로드 404 (목록의 파일이 삭제됨) | DirectUrl |
| 0x80072F0D (-2147012851) | 인증서 신뢰 실패 | 루트 인증서 갱신 제안 |

---

## 8. 미해결 과제 (우선순위 순)

1. **카카오톡 해시 불일치** (2026-10-21 사용자 로그): `Kakao.KakaoTalk`이 0x8A150011로 실패하고, `--ignore-security-hash` 재시도도 같은 코드로 실패합니다. 크롬, 웨일, 허니뷰와 같은 패턴입니다.
   - **2026-11-08 적용**: `DirectUrl='https://app-pc.kakaocdn.net/talk/win32/x64/KakaoTalk_Setup.exe'` + `DirectArgs='/S'`. 주소와 유형(nullsoft)은 `winget show --id Kakao.KakaoTalk`(목록 버전 26.9.2.5342)로 확인했고, 주소가 200 응답(약 92MB)을 주는 것도 확인했습니다. **실제 설치 결과(`/S` 무인 설치, 설치 확인 감지)는 아직 테스트하지 않았습니다.**
   - 범용 대체 경로(`winget show`로 주소·종류를 읽어 직접 설치)는 **다운로드 오류용으로 구현됨**(7장 'winget 다운로드 실패 대응'). 해시 불일치(0x8A150011)는 아직 `--ignore-security-hash` 재시도를 먼저 하고, 그것도 다운로드 오류로 끝날 때만 대체 다운로드로 갑니다. 해시 불일치에도 바로 대체 다운로드(서명 확인)를 쓰게 할지는 검토 과제입니다.
   - `--ignore-security-hash`가 왜 효과가 없는지(관리자 설정 `InstallerHashOverride`, 그룹 정책)는 확인하지 못했습니다.
2. ~~Gemini UI 실기 검증 안 됨~~ **2026-11-08 해결**: Gemini XAML의 `<Setter Property="Template">` 6곳이 `<Setter.Value>` 없이 템플릿을 바로 담고 있어 .NET Framework WPF에서 `XamlParseException`("Setter 형식에 내용 속성이 없습니다")이 났고, EXE가 **아무 표시 없이 꺼졌습니다**(런처는 종료되지 않는 오류를 표시하지 않음). 6곳을 `<Setter.Value>`로 감싸 해결했고, 창 불러오기 실패는 `throw`로 바꿔 런처 오류 창에 내용이 보이게 했습니다. Windows 11에서 관리자 권한을 뺀 같은 런처로 창이 정상으로 뜨는 것을 캡처로 확인했습니다(관리자 권한 EXE 자체 실행은 사용자 확인 필요).
   - XAML을 고친 뒤에는 `[Windows.Markup.XamlReader]::Parse`로 **Windows PowerShell 5.1에서** 직접 읽어 보세요. 리눅스에서는 이 오류를 잡을 수 없습니다. `docs/gemini/1_main_window.xaml` 원본에도 같은 문제가 있습니다.
3. ~~상태 배지 색상표~~ **2026-11-08 해결**: ArtisanOS 토큰으로 통일(5장).
3-1. **실기 설치 결과 (2026-11-08, 이 PC, 관리자 권한 배포 EXE)**: Comet·벅스·멜론·어사이드·Dia·애플뮤직·파이썬·자바, 브레이브·오페라·파이어폭스·Zoom·반디뷰·허니뷰·Acrobat·WinRAR·Quick Share·Chrome Remote Desktop·PC Manager·스팀·블리자드·에픽, foobar2000·7-Zip·Everything(대체 다운로드) 모두 설치·감지 확인. 지니뮤직은 InstallShield 마법사라 사용자가 직접 진행. 고친 것: 어사이드 시간 초과(`-Wait` 자식 대기), Dia 감지(앱 패키지 `TheBrowserCompany.Dia` → `Appx`), 지니뮤직 감지(게시자 "지니뮤직" → `Publisher`에 추가, `지니파일`과 구분), Dia·어사이드는 실제로 조용히 설치되어 `Interactive` 제거.
4. **감지 미확인 항목**: 텔레그램(`%APPDATA%\Telegram Desktop\Telegram.exe`는 추정), 엣지(`msedge.exe` 파일까지는 미확인), Gemini 데스크톱(설치 경로·패키지명 미확인).
5. **블리자드**: 무인 설치 옵션이 없어 `--interactive`로 설치 창을 띄웁니다. 설치 창이 숨는지 실제로 확인한 적이 없습니다.
6. **AIMP 인증서**: 한 PC(커스텀 윈도우로 추정)에서 `aimp.ru` 인증서를 신뢰하지 못했습니다. 루트 인증서 갱신 기능이 실제로 해결하는지는 미확인입니다.
7. **"설치 중… 0:33"이 끝난 뒤에도 남던 문제**: 원인이 확정되지 않았습니다. 완료 창 비동기화와 남은 상태 정리로 대응만 했습니다.
8. **백신 오탐 / SmartScreen**: 코드 서명이 근본 해결책입니다(미진행). 오탐 신고(CrowdStrike, Symantec, Elastic 등)도 아직 하지 않았습니다.
9. (아이디어 단계) winget이 없는 PC에서 App Installer를 자동으로 설치하는 기능(런타임 다운로드 방식 권장), 업데이트 탭.

---

## 9. 테스트 체크리스트 (Windows)

- [ ] EXE 실행 시 UAC가 한 번만 뜨고 창이 정상으로 뜨는지 (콘솔 창 없음)
- [ ] 카테고리, 검색, 전체 선택이 동작하는지. 설치된 항목은 선택되지 않는지
- [ ] 44개의 설치됨/미설치 표시가 실제 PC 상태와 맞는지
- [ ] 제목 표시줄: 끌어서 이동, 두 번 클릭 최대화, 최소화/최대화/닫기 버튼, 최대화 시 가장자리 잘림 없음
- [ ] Pretendard 글꼴로 보이는지 (`%LOCALAPPDATA%\ArtisanOS\Fonts`에 .otf 3개가 생기는지)
- [ ] 새 앱 9개 설치 결과 (8장 3-1)
- [ ] winget 상태 카드가 버전을 표시하는지
- [ ] 미설치 앱 몇 개를 설치 → 경과 시간 표시, 완료/실패 배지, 로그 `└` 줄, 완료 창
- [ ] 크롬·웨일·허니뷰·AIMP 직접 설치 → "설치 확인됨"
- [ ] 카카오톡(해시 불일치) 결과
- [ ] winget 다운로드 실패 대응: 인터넷이 불안정한 PC나 `PI_TEST_WG_DLFAIL=1`로 실행 → 로그에 "대체 다운로드" 줄, 실제 설치 완료 / 끝까지 실패 시 페이지 안내 창
- [ ] 설치 중 창을 닫을 때 확인 창이 뜨는지
- [ ] `install_log.txt`가 EXE 폴더에 생기는지

로그를 볼 때 첫 줄의 `(N개, 한 번에 하나씩 순차 설치)`로 최신 빌드인지 확인하세요. 사용자가 예전 EXE로 테스트한 적이 여러 번 있습니다.
