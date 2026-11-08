# 필수 프로그램 설치 도구 (by Artisan)

윈도우를 새로 깔고 자주 쓰는 프로그램을 골라 한 번에 설치하는 도구입니다.
winget을 기반으로 하며, ArtisanOS와 같은 디자인의 WPF 화면을 씁니다.

**다운로드:** [Releases](../../releases/latest)에서 `ArtisanEssentialInstaller_v2.0.0.exe`를 받으세요. 화면에는 "필수프로그램설치도구_v2.0_정식판.exe"로 표시됩니다(GitHub가 첨부 파일 이름의 한글을 지워서 영문 이름으로 올렸습니다).

## 사용 방법

1. EXE를 실행하고, 관리자 권한 창에서 '예'를 누릅니다.
2. 설치할 프로그램을 체크하고 **'선택 항목 담기'**를 누릅니다. 왼쪽 카테고리나 위쪽 검색창으로 찾을 수 있습니다.
3. 왼쪽 아래 **'담은 항목'**으로 가서 **'순차 설치 시작'**을 누릅니다.

- 담은 순서대로 한 번에 하나씩 설치합니다(순차 설치). 지금 무엇을 어떻게 설치하는지가 항목마다 표시됩니다.
- 실패하면 그 자리에서 바로 다시 시도합니다. winget이 끝내 설치하지 못하면 도구가 공식 설치 파일을 직접 받아 검증한 뒤 설치합니다(대체 다운로드).
- 이미 설치된 프로그램은 '설치됨'으로 표시되고 선택되지 않습니다.
- 문제가 생기면 '로그' 버튼으로 `install_log.txt`를 열어 [커뮤니티](https://discord.gg/EeR5bbF68A)에 보내 주세요.

## 지원 프로그램 (44개)

| 분류 | 프로그램 |
|---|---|
| 브라우저 | 크롬, 브레이브, 오페라, 파이어폭스, 엣지, 웨일, Comet, Dia, 어사이드 |
| 메신저&협업 | 카카오톡, 디스코드, 텔레그램, Zoom |
| 동영상 플레이어 | 팟플레이어, PLEX |
| 음악 플레이어 | foobar2000, PLEXAMP, AIMP, 벅스, 멜론, 지니뮤직, 애플뮤직 |
| 뷰어 | 반디뷰, 허니뷰, Adobe Acrobat Reader |
| 압축 프로그램 | 7-Zip, WinRAR, 반디집 |
| 유틸리티 | Everything, Quick Share, StartAllBack, Chrome Remote Desktop, Microsoft PC Manager |
| 게임런처 | 스팀, 블리자드(Battle.net), 에픽 게임 런처 |
| AI Tool | Claude, ChatGPT/Codex, Gemini |
| 개발 | VSCode, Notepad++, Git, 파이썬, 자바(JDK) |

웨일·블리자드·지니뮤직은 조용히 설치하는 옵션이 없어 설치 창이 뜹니다.

## 동작 방식

- `installer.ps1`: PowerShell 5.1 + WPF로 만든 본체입니다.
- `Launcher.cs`: .NET Framework 4.x 런처입니다. 임시 파일이나 `powershell.exe`를 띄우지 않고, EXE 안에서 PowerShell 엔진을 직접 불러 스크립트를 실행합니다. 관리자 권한은 시작할 때 한 번만 받습니다.
- 설치 순서: winget → (실패) 같은 방법으로 재시도 → (계속 실패) **대체 다운로드**.
  - 대체 다운로드는 winget 목록의 공식 설치 파일 주소를 읽어 직접 받습니다.
  - 받는 방법은 Invoke-WebRequest → curl.exe → BITS 순서로 시도합니다.
  - 받은 파일은 SHA256이나 디지털 서명을 확인한 뒤, winget 매니페스트의 무인 설치 옵션으로 설치합니다.
- 해시가 자주 어긋나는 일부 프로그램(크롬, 웨일, 카카오톡 등)은 제조사 공식 주소에서 직접 받아 설치합니다.

자세한 구조와 이력은 [CLAUDE.md](CLAUDE.md)(인수인계 문서)에 있습니다.

## 빌드 (Windows)

```powershell
powershell -ExecutionPolicy Bypass -File .\build.ps1
```

- .NET Framework 4.x에 기본으로 들어 있는 `csc.exe`를 씁니다.
- `icons\*.png`는 스크립트 안에 base64로 들어가고, `Fonts\*.otf`는 EXE 리소스로 들어갑니다.
- 결과물은 `필수프로그램설치도구_v2.0_정식판.exe`입니다.

## 포함된 자료

- 글꼴: [Pretendard](https://github.com/orioncactus/pretendard) (SIL Open Font License 1.1, `Fonts/LICENSE.txt`)
- 프로그램 아이콘: 각 프로그램을 알아보기 위해 넣은 것으로, 해당 제조사의 상표·저작물입니다.
