# 요청: Windows 프로그램 설치 도구의 UI 디자인 (WPF XAML)

## 1. 앱 소개
- 이름: 필수 프로그램 설치 도구 (부제: by Artisan)
- 용도: 윈도우 포맷 후 자주 쓰는 프로그램 35개를 체크해서 한 번에 자동 설치하는 도구 (winget 기반)
- 사용자: 일반 PC 사용자, 한국어 UI
- 분위기: Windows 11 Fluent 디자인, UniGetUI(WingetUI)와 비슷한 깔끔한 스타일. 라이트 테마 기준.

## 2. 기술 조건 (중요)
- PowerShell 5.1이 XamlReader로 읽어 들이는 순수 WPF XAML(.NET Framework 4.x)입니다.
- 코드 비하인드, x:Class, 이벤트 핸들러 속성(Click="..."), 바인딩용 ViewModel은 쓰지 마세요. 동작은 제가 코드에서 x:Name으로 찾아서 붙입니다.
- 외부 라이브러리(MahApps, ModernWpf, NuGet 등)와 외부 이미지 파일은 쓰지 마세요. 아이콘은 Path(벡터)나 Segoe Fluent Icons / Segoe MDL2 Assets 글꼴로 처리해 주세요.
- 글꼴: Segoe UI Variable Text, Segoe UI, Malgun Gothic (한글 대비)
- 창 크기: 기본 1120×740, 최소 920×560, 화면 가운데에서 시작
- 스타일(버튼, 체크박스, 스크롤바, 입력칸 등)은 Window.Resources 안에 직접 정의해 주세요.

## 3. 화면 구성
### 왼쪽 사이드바 (폭 약 230px)
- 맨 위: 앱 로고(파란 둥근 사각형 + 다운로드 화살표 아이콘), "필수 프로그램 설치 도구", 그 아래 작은 글씨로 "by Artisan"
- 카테고리 목록: 버튼 형태, 오른쪽에 개수 표시, 선택된 항목은 왼쪽에 세로 강조 막대 + 배경 강조
  카테고리: 전체(35), 브라우저(6), 메신저&협업(4), 동영상 플레이어(2), 음악 플레이어(3), 뷰어(3), 압축 프로그램(3), 유틸리티(4), 게임런처(3), AI Tool(3), 개발(3)
- 맨 아래: winget 상태 카드 (작은 제목 "winget", 상태 점(초록/파랑/주황/빨강) + 상태 글자, 예: "사용 가능 v1.12")

### 오른쪽 본문
- 상단: 현재 카테고리 제목(크게), 설명 한 줄("설치할 프로그램을 골라주세요. 이미 설치된 프로그램은 '설치됨'으로 표시됩니다."), 오른쪽에 검색창(돋보기 아이콘 + "프로그램 검색" 안내 문구)
- 목록 머리줄: [전체선택 체크박스] 이름 | winget ID | 상태
- 프로그램 목록(세로 스크롤): 한 줄씩 카드 형태 (아래 4번)
- 검색 결과가 없을 때 가운데에 "검색 결과가 없습니다" 안내
- 하단 바: 설치 경로 입력칸(비어 있으면 "기본 경로에 설치" 안내 문구) + [찾아보기] 버튼 | "N개 선택됨" 표시 | [로그] 버튼 | 강조색 [선택한 프로그램 설치] 버튼

## 4. 프로그램 한 줄(행) 디자인 — 별도 XAML 조각으로
- 높이 약 56px, 둥근 모서리, 마우스를 올리면 살짝 강조
- 구성: 체크박스 | 아이콘(40×40 둥근 타일 위에 32×32 프로그램 아이콘) | 이름(굵게) + 카테고리(작게, 회색) | winget ID(고정폭 글꼴, 예: Google.Chrome) | 상태 배지(둥근 알약 모양)
- 상태 배지 종류(색은 제안해 주세요):
  확인 중… / 미설치(배지 없이 회색 글자) / 설치됨 / 대기 중 / 설치 중… 1:23(경과 시간 표시) / 확인 중… / 완료 / 실패 / 확인 필요 / 건너뜀
- 이미 설치된 줄은 체크박스가 비활성(흐리게) 상태가 됩니다. 이 상태도 보기 좋게 디자인해 주세요.

## 5. 필수 조건: 아래 x:Name을 반드시 그대로 사용
### 메인 창
- NavPanel (StackPanel): 카테고리 버튼이 코드로 추가될 빈 패널
- WgDot (Ellipse), WgText (TextBlock): winget 상태 점/글자
- CatTitle (TextBlock): 카테고리 제목
- SearchBox (TextBox), SearchHint (TextBlock): 검색창과 그 안의 안내 문구(입력하면 코드가 숨김)
- AllCheck (CheckBox): 전체 선택
- ListPanel (StackPanel): 프로그램 행이 코드로 추가될 빈 패널 (ScrollViewer 안)
- EmptyText (TextBlock): 검색 결과 없음 안내 (기본 Collapsed)
- PathBox (TextBox), PathHint (TextBlock), BrowseBtn (Button): 설치 경로
- SelText (TextBlock): "0개 선택됨"
- LogBtn (Button): 로그 보기
- InstallBtn (Button) 안의 InstallText (TextBlock): 설치 버튼과 그 글자("선택한 프로그램 설치" ↔ "설치 중…")

### 카테고리 버튼 조각 (Button 하나, Style 이름: NavButton)
- 루트는 Button, 안에 x:Name="ind" (선택 표시 막대, 기본 Collapsed), x:Name="nm" (카테고리 이름 TextBlock), 그리고 개수 TextBlock
- 선택 상태는 코드에서 ind 표시 + nm 굵게 + 버튼 배경으로 바꿉니다. 그 배경색도 알려 주세요.

### 프로그램 행 조각 (Border 하나)
- x:Name="cb" (CheckBox, Style 이름: FluentCheck)
- x:Name="tile" (Border, 아이콘이 없을 때 보이는 이니셜 타일), x:Name="img" (Image, 기본 Collapsed)
- x:Name="pill" (Border, 상태 배지), 그 안의 x:Name="st" (TextBlock, 상태 글자)
- 이름/카테고리/ID 글자는 제가 넣으니 예시 값으로 채워 주세요.

## 6. 받고 싶은 결과물
1. 메인 창 전체 XAML (Window, Window.Resources 포함, 위 x:Name 전부 포함)
2. 카테고리 버튼 XAML 조각 1개
3. 프로그램 행 XAML 조각 1개
4. 상태 배지 10종의 배경색/글자색 표 (예: 설치됨 = 배경 #DFF6DD / 글자 #0E5C0E)
5. 가능하면 미리 볼 수 있는 HTML 목업도 같이 (선택)