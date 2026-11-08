Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase, System.Windows.Forms, System.Drawing

# 프로그램 버전 (화면 왼쪽 아래와 로그에 표시). Launcher.cs 의 AssemblyVersion/AssemblyFileVersion 과 함께 올릴 것
$AppVersion = '2.0.0'

# EXE로 실행되면 런처가 PI_SCRIPT_DIR에 EXE 폴더를 넘겨줌 (없으면 스크립트 위치 사용)
$ScriptDir = if ($env:PI_SCRIPT_DIR) { $env:PI_SCRIPT_DIR.TrimEnd('\') } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
$LogFilePath   = Join-Path $ScriptDir "install_log.txt"
try {   # EXE 폴더에 쓸 수 없으면(읽기 전용 위치 등) 사용자 폴더에 로그를 남긴다
    $probe = Join-Path $ScriptDir ".pi_write_test"
    [IO.File]::WriteAllText($probe, ''); Remove-Item $probe -Force
} catch {
    $logDir = Join-Path $env:LOCALAPPDATA 'ProgramInstaller'
    try { New-Item -ItemType Directory -Force -Path $logDir | Out-Null } catch { }
    $LogFilePath = Join-Path $logDir 'install_log.txt'
}
$CustomIconDir = Join-Path $ScriptDir "icons"      # 여기에 <winget ID>.png/.ico 넣으면 그 아이콘이 최우선

# 카테고리별 프로그램 목록
#   Name    : 화면에 보이는 이름
#   Id      : winget ID (Source="msstore"면 Microsoft Store ID)
#   Source  : 생략하면 winget, Store 앱은 "msstore"
#   Match   : '설치된 앱' 목록(레지스트리 제거 정보)의 표시 이름과 맞춰볼 정규식 - 설치됨 판정 + 아이콘 추출용
#   Publisher: (선택) 이름이 같은 다른 회사 프로그램과 구분할 때 게시자 정규식
#   Appx    : Store 앱 패키지 이름 정규식 (Get-AppxPackage) - 설치됨 판정용
#   Portable: winget에 없는 포터블 프로그램 -> EXE 옆의 이 이름 폴더를 복사하고 바로가기 생성
#   winget에서 계속 실패하는 프로그램은 Id 대신 File(같은 폴더의 설치파일), Args, PathTemplate, VerifyPath 사용 가능
$Categories = [ordered]@{
    "브라우저" = @(
        @{Name="크롬";        Id="Google.Chrome";            Match='^Google Chrome$'; IgnoreHash=$true; DirectUrl='https://dl.google.com/dl/chrome/install/googlechromestandaloneenterprise64.msi'; Paths=@('%ProgramFiles%\Google\Chrome\Application\chrome.exe', '%ProgramFiles(x86)%\Google\Chrome\Application\chrome.exe', '%LOCALAPPDATA%\Google\Chrome\Application\chrome.exe')},
        @{Name="브레이브";    Id="Brave.Brave";              Match='^Brave$'; Paths=@('%LOCALAPPDATA%\BraveSoftware\Brave-Browser\Application\brave.exe', '%ProgramFiles%\BraveSoftware\Brave-Browser\Application\brave.exe')},
        @{Name="오페라";      Id="Opera.Opera";              Match='^Opera( Stable)?( [\d.]+)?$'; Paths=@('%LOCALAPPDATA%\Programs\Opera\opera.exe', '%ProgramFiles%\Opera\opera.exe')},
        @{Name="파이어폭스";  Id="Mozilla.Firefox";          Match='^Mozilla Firefox( [\d.]+)?( \(.+\))?$'; Paths=@('%ProgramFiles%\Mozilla Firefox\firefox.exe', '%LOCALAPPDATA%\Mozilla Firefox\firefox.exe')},
        @{Name="엣지";        Id="Microsoft.Edge";           Match='^Microsoft Edge$'; Paths=@('%ProgramFiles(x86)%\Microsoft\Edge\Application\msedge.exe', '%ProgramFiles%\Microsoft\Edge\Application\msedge.exe')},
        @{Name="웨일";        Id="NAVER.Whale";              Match='^(Naver Whale|네이버 웨일|Whale)( [\d.]+)?$'; DirectUrl='https://installer-whale.pstatic.net/downloads/sa_installers/WhaleSetupX64.exe'; DirectArgs=''; Interactive=$true; Paths=@('%ProgramFiles%\Naver\Naver Whale\Application\whale.exe', '%ProgramFiles(x86)%\Naver\Naver Whale\Application\whale.exe', '%LOCALAPPDATA%\Naver\Naver Whale\Application\whale.exe')
          Note='웨일 설치 프로그램은 /silent로 실행하면 설치 단계를 건너뛰고 바로 끝나므로(직접 분석해 확인), 설치 창을 띄워 진행합니다.'}
        # 2026-11-08 추가. Comet: winget 목록 주소가 '항상 최신'이라 해시 불일치 위험 -> 공식 주소 직접 설치(winget 목록의 무인 옵션 --install --silent)
        @{Name="Comet";       Id="Perplexity.Comet";         Match='^(Perplexity )?Comet$'; Publisher='Perplexity'; DirectUrl='https://www.perplexity.ai/rest/browser/download?platform=win_x64&channel=stable'; DirectArgs='--install --silent'
          Paths=@('%ProgramFiles%\Perplexity\Comet\Application\comet.exe', '%LOCALAPPDATA%\Perplexity\Comet\Application\comet.exe')},
        # Dia / 어사이드: winget·Store 에 없음 -> 공식 사이트 직접 설치(DirectOnly). 무인 옵션 미확인이라 설치 창 방식(최대 300초 대기)
        @{Name="Dia";         Id="TheBrowserCompany.Dia";    DirectOnly=$true; Appx='^TheBrowserCompany\.Dia'; Match='^Dia( Browser)?$'; Publisher='Browser Company'; Page='https://www.diabrowser.com/'; DirectUrl='https://releases.diabrowser.com/windows/release/DiaInstaller.exe'; DirectArgs='--silent'
          Note='winget에 없어 공식 사이트(diabrowser.com)에서 직접 받아 설치합니다. Windows 11 권장.'},
        @{Name="어사이드";    Id="AtYourSide.Aside";         DirectOnly=$true; Match='^Aside'; Publisher='At Your Side|Aside'
          DirectUrl='https://releases.aside.com/dev-updater/windows/1.0.1022.1/AsideInstaller-1.0.1022.1-win-x64.exe'; DirectArgs=''
          DirectPage='https://aside.com/download?os=win'; DirectPattern='https://releases\.aside\.com/[\w\./\-]+?-win-x64\.exe'
          Note='winget에 없어 공식 사이트(aside.com)에서 최신 설치 파일을 찾아 설치합니다.'}
    )
    "메신저&협업" = @(
        @{Name="카카오톡";    Id="Kakao.KakaoTalk";          Match='^(카카오톡|KakaoTalk)'; DirectUrl='https://app-pc.kakaocdn.net/talk/win32/x64/KakaoTalk_Setup.exe'; DirectArgs='/S'; Paths=@('%ProgramFiles%\Kakao\KakaoTalk\KakaoTalk.exe', '%ProgramFiles(x86)%\Kakao\KakaoTalk\KakaoTalk.exe')},
        @{Name="디스코드";    Id="Discord.Discord";          Match='^Discord$'; Paths=@('%LOCALAPPDATA%\Discord\Update.exe')},
        @{Name="텔레그램";    Id="Telegram.TelegramDesktop"; Match='^Telegram Desktop'; Appx='^TelegramMessengerLLP\.|^Telegram'; Paths=@('%APPDATA%\Telegram Desktop\Telegram.exe')},
        @{Name="Zoom";        Id="Zoom.Zoom";                Match='^Zoom( Workplace)?( \((32|64)-bit\))?$'; Paths=@('%ProgramFiles%\Zoom\bin\Zoom.exe', '%APPDATA%\Zoom\bin\Zoom.exe')}
    )
    "동영상 플레이어" = @(
        @{Name="팟플레이어";  Id="Daum.PotPlayer";           Match='PotPlayer|팟\s?플레이어'
          Paths=@('%ProgramFiles%\DAUM\PotPlayer\PotPlayerMini64.exe', '%ProgramFiles(x86)%\DAUM\PotPlayer\PotPlayerMini.exe')},
        @{Name="PLEX";        Id="Plex.Plex";                Match='^Plex( for Windows)?$'; Paths=@('%ProgramFiles%\Plex\Plex\Plex.exe', '%LOCALAPPDATA%\Programs\Plex\Plex.exe')}
    )
    "음악 플레이어" = @(
        @{Name="foobar2000";  Id="PeterPawlowski.foobar2000"; Match='^foobar2000'; Paths=@('%ProgramFiles%\foobar2000\foobar2000.exe', '%ProgramFiles(x86)%\foobar2000\foobar2000.exe')},
        @{Name="PLEXAMP";     Id="Plex.Plexamp";             Match='^Plexamp'; Paths=@('%LOCALAPPDATA%\Plexamp\Plexamp.exe', '%LOCALAPPDATA%\Programs\Plexamp\Plexamp.exe')},
        @{Name="AIMP";        Id="AIMP.AIMP";                Match='^AIMP\b'; DirectUrl='https://aimp.ru/?do=download.file&id=3'; DirectArgs='/AUTO /SILENT'; Paths=@('%ProgramFiles%\AIMP\AIMP.exe', '%ProgramFiles(x86)%\AIMP\AIMP.exe')},
        # 2026-11-08 추가. 벅스·멜론: winget 목록 주소가 '항상 최신'(카카오톡과 같은 해시 불일치 위험) -> 공식 주소 직접 설치, NSIS /S
        @{Name="벅스";        Id="NHNBugs.Bugs";             Match='벅스|^Bugs'; Publisher='Bugs|NHN'; DirectUrl='https://dl.bugsm.co.kr/BugsPlayer4/BugsSetup.exe'; DirectArgs='/S'},
        @{Name="멜론";        Id="KakaoEntertainmentCorp.MelonPlayer"; Match='멜론|^Melon'; Publisher='Kakao|Melon'; DirectUrl='https://cdnimg.melon.co.kr/svc/pcp/apps/MelonSetup.exe'; DirectArgs='/S'},
        # 지니: winget·Store 에 없음. InstallShield(InstallScript) 설치라 응답 파일 없이는 무인 설치 불가 -> 설치 창 방식
        @{Name="지니뮤직";    Id="GenieMusic.GeniePlayer";   DirectOnly=$true; Match='지니뮤직|^genie'; Publisher='Genie|KT|지니뮤직'; Interactive=$true
          DirectUrl='https://download.genie.co.kr/genie/pcplayer/geniemusic.1.1.2.20_setup.exe'; DirectArgs=''
          DirectPage='https://www.genie.co.kr/guide/geniePC'; DirectPattern='https://download\.genie\.co\.kr/genie/pcplayer/[\w\.\-]+_setup\.exe'
          Note='winget에 없어 공식 사이트(genie.co.kr)에서 받아 설치 창을 띄웁니다. 창에서 설치를 진행해 주세요.'},
        @{Name="애플뮤직";    Id="9PFHDD62MXS1"; Source="msstore"; Appx='^AppleInc\.AppleMusic'}
    )
    "뷰어" = @(
        @{Name="반디뷰";      Id="Bandisoft.BandiView";      Match='^(BandiView|반디뷰)'; Paths=@('%ProgramFiles%\BandiView\BandiView.exe')},
        @{Name="허니뷰";      Id="Bandisoft.Honeyview";      Match='^(Honeyview|꿀뷰)'; DirectUrl='https://bandisoft.app/honeyview/HONEYVIEW-SETUP.EXE'; DirectArgs='/S'; Paths=@('%ProgramFiles%\Honeyview\Honeyview.exe', '%ProgramFiles(x86)%\Honeyview\Honeyview.exe')},
        @{Name="Adobe Acrobat Reader"; Id="Adobe.Acrobat.Reader.64-bit"; Match='^Adobe Acrobat( Reader)?\b'; Paths=@('%ProgramFiles%\Adobe\Acrobat DC\Acrobat\Acrobat.exe', '%ProgramFiles(x86)%\Adobe\Acrobat Reader DC\Reader\AcroRd32.exe')}
    )
    "압축 프로그램" = @(
        @{Name="7-Zip";       Id="7zip.7zip";                Match='^7-Zip'; Paths=@('%ProgramFiles%\7-Zip\7zFM.exe', '%ProgramFiles(x86)%\7-Zip\7zFM.exe')},
        @{Name="WinRAR";      Id="RARLab.WinRAR";            Match='^WinRAR'; Paths=@('%ProgramFiles%\WinRAR\WinRAR.exe', '%ProgramFiles(x86)%\WinRAR\WinRAR.exe')},
        @{Name="반디집";      Id="Bandisoft.Bandizip";       Match='^(Bandizip|반디집)'; Paths=@('%ProgramFiles%\Bandizip\Bandizip.exe')}
    )
    "유틸리티" = @(
        @{Name="Everything";  Id="voidtools.Everything";     Match='^Everything\b'; Paths=@('%ProgramFiles%\Everything\Everything.exe', '%ProgramFiles(x86)%\Everything\Everything.exe')},
        @{Name="Quick Share"; Id="Google.QuickShare";        Match='^Quick Share'; Appx='^NearbyShare$'; Publisher='Google'; Paths=@('%ProgramFiles%\Google\NearbyShare\nearby_share.exe')},
        @{Name="StartAllBack"; Id="StartIsBack.StartAllBack"; Match='^StartAllBack'; Paths=@('%LOCALAPPDATA%\StartAllBack\StartAllBackCfg.exe', '%ProgramFiles%\StartAllBack\StartAllBackCfg.exe')},
        @{Name="Chrome Remote Desktop"; Id="Google.ChromeRemoteDesktopHost"; Match='^Chrome Remote Desktop'; Paths=@('%ProgramFiles(x86)%\Google\Chrome Remote Desktop\CurrentVersion', '%ProgramFiles%\Google\Chrome Remote Desktop\CurrentVersion')},
        @{Name="Microsoft PC Manager"; Id="9PM860492SZD"; Source="msstore"; Appx='PCManager'}
    )
    "게임런처" = @(
        @{Name="스팀";        Id="Valve.Steam";              Match='^Steam$'; Paths=@('%ProgramFiles(x86)%\Steam\steam.exe', '%ProgramFiles%\Steam\steam.exe')},
        @{Name="블리자드";    Id="Blizzard.BattleNet";       Match='^Battle\.net'; DefaultLocation='%ProgramFiles(x86)%\Battle.net'; Interactive=$true; Paths=@('%ProgramFiles(x86)%\Battle.net\Battle.net Launcher.exe')},
        @{Name="에픽 게임 런처"; Id="EpicGames.EpicGamesLauncher"; Match='^Epic Games Launcher'; Paths=@('%ProgramFiles(x86)%\Epic Games\Launcher\Portal\Binaries\Win64\EpicGamesLauncher.exe', '%ProgramFiles%\Epic Games\Launcher\Portal\Binaries\Win64\EpicGamesLauncher.exe', '%ProgramFiles(x86)%\Epic Games\Launcher\Portal', '%ProgramFiles%\Epic Games\Launcher\Portal')}
    )
    "AI Tool" = @(
        @{Name="Claude";      Id="Anthropic.Claude";         Match='^Claude$'; Appx='^(Claude|Anthropic)'},
        @{Name="ChatGPT/Codex"; Id="9PLM9XGG6VKS"; Source="msstore"; Appx='ChatGPT|Codex'},
        @{Name="Gemini";      Id="Google.GeminiDesktop";     Match='^Gemini\b'; Appx='Gemini'}
    )
    "개발" = @(
        @{Name="VSCode";      Id="Microsoft.VisualStudioCode"; Match='^Microsoft Visual Studio Code( \((User|System)\))?$'; Paths=@('%LOCALAPPDATA%\Programs\Microsoft VS Code\Code.exe', '%ProgramFiles%\Microsoft VS Code\Code.exe')},
        @{Name="Notepad++";   Id="Notepad++.Notepad++";      Match='^Notepad\+\+'; Paths=@('%ProgramFiles%\Notepad++\notepad++.exe', '%ProgramFiles(x86)%\Notepad++\notepad++.exe')},
        @{Name="Git";         Id="Git.Git";                  Match='^Git( version [\d.]+)?$'; Paths=@('%ProgramFiles%\Git\cmd\git.exe', '%ProgramFiles(x86)%\Git\cmd\git.exe')},
        # 2026-11-08 추가. 파이썬 3.14(최신 안정), 자바 = Eclipse Temurin JDK 25 (LTS, 무료 OpenJDK 배포판). 둘 다 winget 목록의 버전 고정 주소라 해시 문제 없음
        @{Name="파이썬";      Id="Python.Python.3.14";       Match='^Python 3\.14\.\d+ .*\(64-bit\)$'; Publisher='Python Software Foundation'
          Paths=@('%LOCALAPPDATA%\Programs\Python\Python314\python.exe', '%ProgramFiles%\Python314\python.exe')},
        @{Name="자바 (JDK)";  Id="EclipseAdoptium.Temurin.25.JDK"; Match='^Eclipse Temurin JDK .*25\.'; Publisher='Eclipse Adoptium'
          Paths=@('%ProgramFiles%\Eclipse Adoptium\jdk-25*\bin\java.exe')}
    )
}

# 내장 아이콘 (빌드할 때 icons 폴더의 PNG가 여기에 자동으로 들어감: winget ID -> base64 PNG)
$EmbeddedIcons = @{}
# @@EMBEDDED_ICONS@@

# ───────────────────────────── 글꼴 (Pretendard) ─────────────────────────────
# ArtisanOS와 같은 방식: EXE에 넣은 Pretendard-*.otf 를 %LOCALAPPDATA%\ArtisanOS\Fonts 에 한 번 풀어 쓴다
# (ArtisanOS와 같은 폴더를 같이 씀). EXE 옆 Fonts 폴더가 있으면 그것을 우선. 둘 다 없으면 시스템 글꼴.
function Resolve-FontDir {
    if (Test-Path -LiteralPath (Join-Path $ScriptDir 'Fonts\Pretendard-Medium.otf')) { return (Join-Path $ScriptDir 'Fonts') }
    try {
        $asm = [Reflection.Assembly]::GetEntryAssembly()
        $has = { param($a) $a -and @($a.GetManifestResourceNames() | Where-Object { $_ -like 'Pretendard-*.otf' }).Count -gt 0 }
        if (-not (& $has $asm) -and $env:PI_EXE_PATH -and (Test-Path $env:PI_EXE_PATH)) { $asm = [Reflection.Assembly]::LoadFile($env:PI_EXE_PATH) }
        if ($asm) {
            $names = @($asm.GetManifestResourceNames() | Where-Object { $_ -like 'Pretendard-*.otf' })
            if ($names.Count) {
                $dir = Join-Path $env:LOCALAPPDATA 'ArtisanOS\Fonts'
                $null = New-Item -ItemType Directory -Force -Path $dir
                foreach ($n in $names) {
                    $dest = Join-Path $dir $n
                    if (-not (Test-Path -LiteralPath $dest)) {
                        $rs = $asm.GetManifestResourceStream($n); $fs = [IO.File]::Create($dest)
                        try { $rs.CopyTo($fs) } finally { $fs.Close(); $rs.Close() }
                    }
                }
                if (Test-Path -LiteralPath (Join-Path $dir 'Pretendard-Medium.otf')) { return $dir }
            }
        }
    } catch { }
    return $null
}
$UiFont = 'Malgun Gothic, Segoe UI'
$FontDir = Resolve-FontDir
if ($FontDir) { $UiFont = [Security.SecurityElement]::Escape(([Uri]([string]$FontDir + '\')).AbsoluteUri + '#Pretendard') + ', Malgun Gothic, Segoe UI' }

# ───────────────────────────── 화면 (WPF) ─────────────────────────────
# 디자인: ArtisanOS(desktop-current/source/ArtisanOS.ps1)와 같은 토큰·스타일 (2026-11-08 통일)
#   canvas #F4F5F7 / surface #FFFFFF / text #1C1F26 / secondary #5B6270 / accent #2557D6 / border #E3E6EB
#   글꼴 Pretendard(EXE 내장) / 기호 Segoe Fluent Icons / 사용자 지정 제목 표시줄(WindowChrome)
# 주의: .NET Framework WPF는 <Setter Property="Template"> 안에 템플릿을 바로 넣으면 안 됨 -> 반드시 <Setter.Value>
$XamlText = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        xmlns:shell="clr-namespace:System.Windows.Shell;assembly=PresentationFramework"
        Title="필수 프로그램 설치 도구 by Artisan"
        Width="1120" Height="740" MinWidth="920" MinHeight="560"
        WindowStartupLocation="CenterScreen" WindowStyle="None" ResizeMode="CanResize"
        Background="#F4F5F7" Foreground="#1C1F26"
        FontFamily="__UIFONT__" FontWeight="Medium" FontSize="13"
        UseLayoutRounding="True" SnapsToDevicePixels="True" TextOptions.TextFormattingMode="Ideal">
    <shell:WindowChrome.WindowChrome>
        <shell:WindowChrome CaptionHeight="44" ResizeBorderThickness="6" GlassFrameThickness="0" CornerRadius="8" UseAeroCaptionButtons="False"/>
    </shell:WindowChrome.WindowChrome>

    <Window.Resources>
        <!-- 색상 토큰 (키 이름은 코드·조각이 DynamicResource로 찾으므로 바꾸지 말 것) -->
        <SolidColorBrush x:Key="AppBackground" Color="#F4F5F7"/>
        <SolidColorBrush x:Key="ContentBackground" Color="#FFFFFF"/>
        <SolidColorBrush x:Key="AccentColor" Color="#2557D6"/>
        <SolidColorBrush x:Key="AccentHover" Color="#1E47B3"/>
        <SolidColorBrush x:Key="TextPrimary" Color="#1C1F26"/>
        <SolidColorBrush x:Key="TextSecondary" Color="#5B6270"/>
        <SolidColorBrush x:Key="BorderColor" Color="#E3E6EB"/>
        <SolidColorBrush x:Key="HoverColor" Color="#EBEDF1"/>
        <SolidColorBrush x:Key="FocusRing" Color="#2557D6"/>
        <FontFamily x:Key="IconFont">Segoe Fluent Icons, Segoe MDL2 Assets</FontFamily>

        <Style TargetType="TextBlock">
            <Setter Property="VerticalAlignment" Value="Center"/>
        </Style>
        <Style TargetType="ToolTip">
            <Setter Property="Background" Value="#1C1F26"/>
            <Setter Property="Foreground" Value="#FFFFFF"/>
            <Setter Property="BorderThickness" Value="0"/>
            <Setter Property="Padding" Value="10,6"/>
            <Setter Property="FontSize" Value="12"/>
        </Style>

        <!-- 스크롤바 (ArtisanOS와 동일) -->
        <Style TargetType="ScrollBar">
            <Setter Property="Width" Value="12"/>
            <Setter Property="Background" Value="Transparent"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="ScrollBar">
                        <Grid Background="Transparent" Margin="3,2">
                            <Track x:Name="PART_Track" IsDirectionReversed="True" Orientation="{TemplateBinding Orientation}">
                                <Track.DecreaseRepeatButton>
                                    <RepeatButton Command="ScrollBar.PageUpCommand" Focusable="False">
                                        <RepeatButton.Template><ControlTemplate TargetType="RepeatButton"><Border Background="Transparent"/></ControlTemplate></RepeatButton.Template>
                                    </RepeatButton>
                                </Track.DecreaseRepeatButton>
                                <Track.Thumb>
                                    <Thumb>
                                        <Thumb.Template>
                                            <ControlTemplate TargetType="Thumb">
                                                <Border x:Name="Handle" Background="#C9CDD5" CornerRadius="3"/>
                                                <ControlTemplate.Triggers>
                                                    <Trigger Property="IsMouseOver" Value="True"><Setter TargetName="Handle" Property="Background" Value="#9AA1AD"/></Trigger>
                                                    <Trigger Property="IsDragging" Value="True"><Setter TargetName="Handle" Property="Background" Value="#5B6270"/></Trigger>
                                                </ControlTemplate.Triggers>
                                            </ControlTemplate>
                                        </Thumb.Template>
                                    </Thumb>
                                </Track.Thumb>
                                <Track.IncreaseRepeatButton>
                                    <RepeatButton Command="ScrollBar.PageDownCommand" Focusable="False">
                                        <RepeatButton.Template><ControlTemplate TargetType="RepeatButton"><Border Background="Transparent"/></ControlTemplate></RepeatButton.Template>
                                    </RepeatButton>
                                </Track.IncreaseRepeatButton>
                            </Track>
                        </Grid>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>
        <Style TargetType="ScrollViewer">
            <Setter Property="HorizontalScrollBarVisibility" Value="Disabled"/>
        </Style>
        <!-- 하이퍼링크: 강조색, 마우스를 올리면 밑줄 -->
        <Style TargetType="Hyperlink">
            <Setter Property="Foreground" Value="#2557D6"/>
            <Setter Property="TextDecorations" Value="{x:Null}"/>
            <Setter Property="Cursor" Value="Hand"/>
            <Style.Triggers>
                <Trigger Property="IsMouseOver" Value="True">
                    <Setter Property="Foreground" Value="#1E47B3"/>
                    <Setter Property="TextDecorations" Value="Underline"/>
                </Trigger>
            </Style.Triggers>
        </Style>

        <!-- 제목 표시줄 버튼 -->
        <Style x:Key="ChromeBtn" TargetType="Button">
            <Setter Property="Foreground" Value="#4A5160"/>
            <Setter Property="Background" Value="Transparent"/>
            <Setter Property="BorderThickness" Value="0"/>
            <Setter Property="Width" Value="46"/>
            <Setter Property="Height" Value="44"/>
            <Setter Property="Focusable" Value="False"/>
            <Setter Property="FontFamily" Value="{StaticResource IconFont}"/>
            <Setter Property="FontSize" Value="10"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border x:Name="C" Background="{TemplateBinding Background}">
                            <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True"><Setter TargetName="C" Property="Background" Value="#E6E8EC"/></Trigger>
                            <Trigger Property="IsPressed" Value="True"><Setter TargetName="C" Property="Background" Value="#D9DCE2"/></Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>
        <Style x:Key="ChromeClose" TargetType="Button" BasedOn="{StaticResource ChromeBtn}">
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border x:Name="C" Background="Transparent">
                            <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True"><Setter TargetName="C" Property="Background" Value="#C42B1C"/><Setter Property="Foreground" Value="White"/></Trigger>
                            <Trigger Property="IsPressed" Value="True"><Setter TargetName="C" Property="Background" Value="#9B2216"/></Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <!-- 카테고리 버튼 (ArtisanOS 사이드바 Step과 동일한 모양). 선택 표시는 코드(Set-Category)가 Background/BorderBrush/Foreground로 -->
        <Style x:Key="NavButton" TargetType="Button">
            <Setter Property="Background" Value="Transparent"/>
            <Setter Property="BorderBrush" Value="Transparent"/>
            <Setter Property="Foreground" Value="#4A5160"/>
            <Setter Property="FontSize" Value="13"/>
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="FocusVisualStyle" Value="{x:Null}"/>
            <Setter Property="HorizontalContentAlignment" Value="Stretch"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Grid Margin="2,1">
                            <Border Panel.ZIndex="1" IsHitTestVisible="False" x:Name="Ring" CornerRadius="9" BorderBrush="{DynamicResource FocusRing}" BorderThickness="2" Opacity="0"/>
                            <Border x:Name="B" Background="{TemplateBinding Background}" BorderBrush="{TemplateBinding BorderBrush}" BorderThickness="1" CornerRadius="7" Margin="2" MinHeight="34">
                                <Grid>
                                    <Border x:Name="Hover" Background="#1C1F26" CornerRadius="6" Opacity="0"/>
                                    <ContentPresenter Margin="12,0,10,0" VerticalAlignment="Center" HorizontalAlignment="Stretch"/>
                                </Grid>
                            </Border>
                        </Grid>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True"><Setter TargetName="Hover" Property="Opacity" Value="0.05"/></Trigger>
                            <Trigger Property="IsPressed" Value="True"><Setter TargetName="Hover" Property="Opacity" Value="0.09"/></Trigger>
                            <Trigger Property="IsKeyboardFocused" Value="True"><Setter TargetName="Ring" Property="Opacity" Value="1"/></Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <!-- 입력칸 (설치 경로) -->
        <Style x:Key="FluentTextBox" TargetType="TextBox">
            <Setter Property="Background" Value="#FFFFFF"/>
            <Setter Property="BorderBrush" Value="#D5D9E0"/>
            <Setter Property="Foreground" Value="#1C1F26"/>
            <Setter Property="CaretBrush" Value="#2557D6"/>
            <Setter Property="BorderThickness" Value="1"/>
            <Setter Property="Padding" Value="10,0"/>
            <Setter Property="VerticalContentAlignment" Value="Center"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="TextBox">
                        <Border x:Name="Bd" Background="{TemplateBinding Background}" BorderBrush="{TemplateBinding BorderBrush}" BorderThickness="{TemplateBinding BorderThickness}" CornerRadius="6">
                            <ScrollViewer x:Name="PART_ContentHost" Margin="{TemplateBinding Padding}" VerticalAlignment="Center"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True"><Setter TargetName="Bd" Property="BorderBrush" Value="#9AA1AD"/></Trigger>
                            <Trigger Property="IsKeyboardFocused" Value="True"><Setter TargetName="Bd" Property="BorderBrush" Value="#2557D6"/></Trigger>
                            <Trigger Property="IsEnabled" Value="False"><Setter TargetName="Bd" Property="Opacity" Value="0.5"/></Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>
        <Style x:Key="SearchField" TargetType="Border">
            <Setter Property="Background" Value="#FFFFFF"/>
            <Setter Property="BorderBrush" Value="#D5D9E0"/>
            <Style.Triggers>
                <Trigger Property="IsMouseOver" Value="True"><Setter Property="BorderBrush" Value="#9AA1AD"/></Trigger>
                <Trigger Property="IsKeyboardFocusWithin" Value="True"><Setter Property="BorderBrush" Value="#2557D6"/></Trigger>
            </Style.Triggers>
        </Style>

        <!-- 체크박스 (ArtisanOS Check와 동일) -->
        <Style x:Key="FluentCheck" TargetType="CheckBox">
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="Foreground" Value="#1C1F26"/>
            <Setter Property="FocusVisualStyle" Value="{x:Null}"/>
            <Setter Property="VerticalContentAlignment" Value="Center"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="CheckBox">
                        <StackPanel Orientation="Horizontal" Background="Transparent">
                            <Grid Width="18" Height="18" VerticalAlignment="Center">
                                <Border Panel.ZIndex="1" IsHitTestVisible="False" x:Name="Ring" CornerRadius="6" Margin="-2" BorderBrush="{DynamicResource FocusRing}" BorderThickness="2" Opacity="0"/>
                                <Border x:Name="Box" CornerRadius="4" Background="#FFFFFF" BorderBrush="#8A909C" BorderThickness="1"/>
                                <TextBlock x:Name="Mark" FontFamily="{DynamicResource IconFont}" Text="&#xE73E;" FontSize="11" Foreground="White" HorizontalAlignment="Center" VerticalAlignment="Center" Opacity="0"/>
                            </Grid>
                            <ContentPresenter Margin="10,0,0,0" VerticalAlignment="Center"/>
                        </StackPanel>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsChecked" Value="True">
                                <Setter TargetName="Box" Property="Background" Value="#2557D6"/>
                                <Setter TargetName="Box" Property="BorderBrush" Value="#2557D6"/>
                                <Setter TargetName="Mark" Property="Opacity" Value="1"/>
                            </Trigger>
                            <Trigger Property="IsMouseOver" Value="True"><Setter TargetName="Box" Property="BorderBrush" Value="#2557D6"/></Trigger>
                            <Trigger Property="IsKeyboardFocused" Value="True"><Setter TargetName="Ring" Property="Opacity" Value="1"/></Trigger>
                            <Trigger Property="IsEnabled" Value="False"><Setter Property="Opacity" Value="0.35"/><Setter Property="Cursor" Value="Arrow"/></Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <!-- 버튼: 보조(StandardBtn) / 강조(PrimaryBtn). ArtisanOS Btn·PrimaryBtn과 동일 (높이 34, 150ms 호버, 포커스 링) -->
        <Style x:Key="StandardBtn" TargetType="Button">
            <Setter Property="HorizontalContentAlignment" Value="Center"/>
            <Setter Property="Foreground" Value="#1C1F26"/>
            <Setter Property="Background" Value="#FFFFFF"/>
            <Setter Property="BorderBrush" Value="#C9CDD5"/>
            <Setter Property="Padding" Value="14,7"/>
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="FontSize" Value="13"/>
            <Setter Property="MinHeight" Value="34"/>
            <Setter Property="FocusVisualStyle" Value="{x:Null}"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Grid>
                            <Border Panel.ZIndex="1" IsHitTestVisible="False" x:Name="Ring" CornerRadius="9" Margin="-2" BorderBrush="{DynamicResource FocusRing}" BorderThickness="2" Opacity="0"/>
                            <Border x:Name="B" Background="{TemplateBinding Background}" BorderBrush="{TemplateBinding BorderBrush}" BorderThickness="1" CornerRadius="6">
                                <Grid>
                                    <Border x:Name="Hover" Background="#1C1F26" CornerRadius="5" Opacity="0"/>
                                    <ContentPresenter Margin="{TemplateBinding Padding}" HorizontalAlignment="{TemplateBinding HorizontalContentAlignment}" VerticalAlignment="Center"/>
                                </Grid>
                            </Border>
                        </Grid>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Trigger.EnterActions><BeginStoryboard><Storyboard><DoubleAnimation Storyboard.TargetName="Hover" Storyboard.TargetProperty="Opacity" To="0.05" Duration="0:0:0.15"/></Storyboard></BeginStoryboard></Trigger.EnterActions>
                                <Trigger.ExitActions><BeginStoryboard><Storyboard><DoubleAnimation Storyboard.TargetName="Hover" Storyboard.TargetProperty="Opacity" To="0" Duration="0:0:0.12"/></Storyboard></BeginStoryboard></Trigger.ExitActions>
                            </Trigger>
                            <Trigger Property="IsPressed" Value="True"><Setter TargetName="Hover" Property="Opacity" Value="0.1"/></Trigger>
                            <Trigger Property="IsKeyboardFocused" Value="True"><Setter TargetName="Ring" Property="Opacity" Value="1"/></Trigger>
                            <Trigger Property="IsEnabled" Value="False"><Setter TargetName="B" Property="Opacity" Value="0.45"/><Setter Property="Cursor" Value="Arrow"/></Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>
        <Style x:Key="PrimaryBtn" TargetType="Button" BasedOn="{StaticResource StandardBtn}">
            <Setter Property="Background" Value="#2557D6"/>
            <Setter Property="BorderBrush" Value="#2557D6"/>
            <Setter Property="Foreground" Value="#FFFFFF"/>
            <Setter Property="FontWeight" Value="SemiBold"/>
        </Style>

        <!-- 프로그램 행: ArtisanOS 선택 카드와 같은 흰 카드 -->
        <Style x:Key="RowStyle" TargetType="Border">
            <Setter Property="Background" Value="#FFFFFF"/>
            <Setter Property="BorderBrush" Value="#E3E6EB"/>
            <Setter Property="BorderThickness" Value="1"/>
            <Setter Property="CornerRadius" Value="8"/>
            <Setter Property="Margin" Value="0,0,0,6"/>
            <Style.Triggers>
                <Trigger Property="IsMouseOver" Value="True">
                    <Setter Property="Background" Value="#FAFBFC"/>
                    <Setter Property="BorderBrush" Value="#C9CDD5"/>
                </Trigger>
            </Style.Triggers>
        </Style>
        <Style x:Key="Panel" TargetType="Border">
            <Setter Property="Background" Value="#FFFFFF"/>
            <Setter Property="BorderBrush" Value="#E3E6EB"/>
            <Setter Property="BorderThickness" Value="1"/>
            <Setter Property="CornerRadius" Value="8"/>
        </Style>
    </Window.Resources>

    <Grid x:Name="RootGrid">
        <Grid.RowDefinitions>
            <RowDefinition Height="44"/>
            <RowDefinition Height="*"/>
        </Grid.RowDefinitions>

        <!-- ===== 제목 표시줄 ===== -->
        <Border Grid.Row="0" Background="#FFFFFF" BorderBrush="#E3E6EB" BorderThickness="0,0,0,1">
            <Grid>
                <Grid.ColumnDefinitions>
                    <ColumnDefinition Width="220"/>
                    <ColumnDefinition Width="*"/>
                    <ColumnDefinition Width="160"/>
                </Grid.ColumnDefinitions>
                <StackPanel Orientation="Horizontal" VerticalAlignment="Center" Margin="16,0,0,0">
                    <Image x:Name="BrandImg" Width="18" Height="18" Margin="0,0,10,0" RenderOptions.BitmapScalingMode="HighQuality"/>
                    <TextBlock Text="필수 프로그램 설치 도구" FontSize="13" FontWeight="Medium"/>
                </StackPanel>
                <Border Grid.Column="1" Style="{StaticResource SearchField}" BorderThickness="1" CornerRadius="7" MaxWidth="420" Height="30" Margin="24,0" shell:WindowChrome.IsHitTestVisibleInChrome="True">
                    <DockPanel Margin="10,0">
                        <TextBlock FontFamily="{StaticResource IconFont}" Text="&#xE721;" Foreground="#5B6270" FontSize="13" Margin="0,0,8,0"/>
                        <Grid>
                            <TextBlock x:Name="SearchHint" Text="프로그램 찾기 (카카오톡, 크롬…)" Foreground="#5B6270" FontSize="13" IsHitTestVisible="False"/>
                            <TextBox x:Name="SearchBox" Background="Transparent" Foreground="#1C1F26" CaretBrush="#2557D6" BorderThickness="0" VerticalContentAlignment="Center" FontSize="13" Padding="0" AutomationProperties.Name="프로그램 찾기"/>
                        </Grid>
                    </DockPanel>
                </Border>
                <StackPanel Grid.Column="2" Orientation="Horizontal" HorizontalAlignment="Right" shell:WindowChrome.IsHitTestVisibleInChrome="True">
                    <Button x:Name="WinMin" Content="&#xE921;" Style="{StaticResource ChromeBtn}" ToolTip="최소화" AutomationProperties.Name="최소화"/>
                    <Button x:Name="WinMax" Content="&#xE922;" Style="{StaticResource ChromeBtn}" ToolTip="최대화" AutomationProperties.Name="최대화"/>
                    <Button x:Name="WinClose" Content="&#xE8BB;" Style="{StaticResource ChromeClose}" ToolTip="닫기" AutomationProperties.Name="닫기"/>
                </StackPanel>
            </Grid>
        </Border>

        <Grid Grid.Row="1">
            <Grid.ColumnDefinitions>
                <ColumnDefinition Width="220"/>
                <ColumnDefinition Width="*"/>
            </Grid.ColumnDefinitions>

            <!-- ===== 사이드바 ===== -->
            <Border BorderBrush="#E3E6EB" BorderThickness="0,0,1,0">
                <DockPanel Margin="10,14,10,12">
                    <Grid DockPanel.Dock="Top" Margin="8,0,0,14">
                        <Grid.ColumnDefinitions>
                            <ColumnDefinition Width="Auto"/>
                            <ColumnDefinition Width="*"/>
                        </Grid.ColumnDefinitions>
                        <Image x:Name="BrandLogo" Width="36" Height="36" RenderOptions.BitmapScalingMode="HighQuality"/>
                        <StackPanel Grid.Column="1" Margin="10,0,0,0" VerticalAlignment="Center">
                            <TextBlock Text="설치 도구" FontSize="13" FontWeight="Medium"/>
                            <TextBlock Text="by Artisan" Foreground="#5B6270" FontSize="12" Margin="0,1,0,0"/>
                        </StackPanel>
                    </Grid>

                    <!-- 맨 아래: 커뮤니티 링크 + 버전 (DockPanel 은 먼저 선언한 Bottom 이 가장 아래) -->
                    <DockPanel DockPanel.Dock="Bottom" Margin="10,10,8,0">
                        <TextBlock x:Name="VerText" DockPanel.Dock="Right" Text="v" FontSize="12" Foreground="#5B6270"/>
                        <TextBlock FontSize="12">
                            <Hyperlink x:Name="CommunityLink" NavigateUri="https://discord.gg/EeR5bbF68A" ToolTip="Discord 커뮤니티 (discord.gg/EeR5bbF68A)" AutomationProperties.Name="커뮤니티 참여하기 (Discord)">
                                <Run FontFamily="{StaticResource IconFont}" Text="&#xE716;"/><Run Text="  커뮤니티 참여하기"/><Run FontFamily="{StaticResource IconFont}" FontSize="10" Text="  &#xE8A7;"/>
                            </Hyperlink>
                        </TextBlock>
                    </DockPanel>

                    <!-- winget 상태 -->
                    <Border DockPanel.Dock="Bottom" Style="{StaticResource Panel}" Padding="12,10" Margin="2,10,2,0">
                        <StackPanel>
                            <TextBlock Text="winget 상태" FontSize="12" Foreground="#5B6270" Margin="0,0,0,4"/>
                            <StackPanel Orientation="Horizontal">
                                <Ellipse x:Name="WgDot" Width="8" Height="8" Fill="#2557D6" VerticalAlignment="Center" Margin="0,0,8,0"/>
                                <TextBlock x:Name="WgText" Text="준비 중…" FontSize="12" FontWeight="SemiBold"/>
                            </StackPanel>
                            <!-- 최신 버전 여부 (GitHub microsoft/winget-cli 최신 정식 릴리스와 비교) -->
                            <TextBlock x:Name="WgSub" Text="" FontSize="12" Foreground="#5B6270" Margin="16,3,0,0" TextWrapping="Wrap" Visibility="Collapsed"/>
                            <Button x:Name="WgUpdateBtn" Style="{StaticResource StandardBtn}" Margin="0,8,0,0" MinHeight="30" Padding="10,4" HorizontalAlignment="Stretch" Visibility="Collapsed">
                                <StackPanel Orientation="Horizontal">
                                    <TextBlock FontFamily="{StaticResource IconFont}" Text="&#xE777;" FontSize="12" Margin="0,0,6,0"/>
                                    <TextBlock x:Name="WgUpdateText" Text="업데이트" FontSize="12"/>
                                </StackPanel>
                            </Button>
                        </StackPanel>
                    </Border>

                    <!-- 담은 항목 (설치 바구니): 여기서 순차 설치를 시작한다 -->
                    <StackPanel DockPanel.Dock="Bottom" Margin="0,8,0,0">
                        <Border Height="1" Background="#E3E6EB" Margin="8,0,8,8"/>
                        <Button x:Name="CartNav" Style="{StaticResource NavButton}" AutomationProperties.Name="담은 항목">
                            <Grid>
                                <Grid.ColumnDefinitions>
                                    <ColumnDefinition Width="Auto"/><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/>
                                </Grid.ColumnDefinitions>
                                <TextBlock x:Name="CartInd" FontFamily="{StaticResource IconFont}" Text="&#xE7BF;" FontSize="15" Width="18" Margin="0,0,10,0"/>
                                <TextBlock x:Name="CartNm" Grid.Column="1" Text="담은 항목" FontSize="13"/>
                                <Border x:Name="CartBadge" Grid.Column="2" Background="#2557D6" CornerRadius="9" MinWidth="20" Height="18" Padding="6,0" Visibility="Collapsed">
                                    <TextBlock x:Name="CartCount" Text="0" Foreground="White" FontSize="11" FontWeight="SemiBold" HorizontalAlignment="Center" VerticalAlignment="Center"/>
                                </Border>
                            </Grid>
                        </Button>
                    </StackPanel>

                    <ScrollViewer VerticalScrollBarVisibility="Auto">
                        <StackPanel x:Name="NavPanel"/>
                    </ScrollViewer>
                </DockPanel>
            </Border>

            <!-- ===== 본문 ===== -->
            <DockPanel Grid.Column="1" Margin="28,20,28,0">
                <StackPanel DockPanel.Dock="Top" Margin="0,0,0,16">
                    <TextBlock Text="프로그램 설치" FontSize="12" Foreground="#5B6270"/>
                    <TextBlock x:Name="CatTitle" Text="전체 프로그램" FontSize="26" FontWeight="Bold" Margin="0,2,0,0"/>
                    <TextBlock x:Name="CatDesc" Text="설치할 프로그램을 체크하고 '선택 항목 담기'를 누르세요. 담은 항목에서 한 번에 설치합니다." FontSize="14" Foreground="#5B6270" Margin="0,4,0,0" TextWrapping="Wrap"/>
                </StackPanel>

                <!-- 하단 바 -->
                <Border DockPanel.Dock="Bottom" BorderBrush="#E3E6EB" BorderThickness="0,1,0,0" Padding="0,12,0,14" Margin="0,8,0,0">
                    <DockPanel>
                        <StackPanel DockPanel.Dock="Right" Orientation="Horizontal">
                            <TextBlock x:Name="SelText" Text="0개 선택됨" Foreground="#5B6270" FontSize="13" Margin="16,0,14,0"/>
                            <Button x:Name="LogBtn" Style="{StaticResource StandardBtn}" Margin="0,0,8,0">
                                <StackPanel Orientation="Horizontal">
                                    <TextBlock FontFamily="{StaticResource IconFont}" Text="&#xE9F9;" FontSize="13" Margin="0,0,8,0"/>
                                    <TextBlock Text="로그"/>
                                </StackPanel>
                            </Button>
                            <Button x:Name="CartClearBtn" Style="{StaticResource StandardBtn}" Margin="0,0,8,0" Visibility="Collapsed">
                                <StackPanel Orientation="Horizontal">
                                    <TextBlock FontFamily="{StaticResource IconFont}" Text="&#xE74D;" FontSize="13" Margin="0,0,8,0"/>
                                    <TextBlock Text="목록 비우기"/>
                                </StackPanel>
                            </Button>
                            <Button x:Name="AddCartBtn" Style="{StaticResource PrimaryBtn}" MinWidth="150">
                                <StackPanel Orientation="Horizontal">
                                    <TextBlock FontFamily="{StaticResource IconFont}" Text="&#xE7BF;" FontSize="13" Foreground="White" Margin="0,0,8,0"/>
                                    <TextBlock Text="선택 항목 담기" Foreground="White" FontWeight="SemiBold"/>
                                </StackPanel>
                            </Button>
                            <Button x:Name="InstallBtn" Style="{StaticResource PrimaryBtn}" MinWidth="170" Visibility="Collapsed">
                                <StackPanel Orientation="Horizontal">
                                    <TextBlock FontFamily="{StaticResource IconFont}" Text="&#xE896;" FontSize="13" Foreground="White" Margin="0,0,8,0"/>
                                    <TextBlock x:Name="InstallText" Text="순차 설치 시작" Foreground="White" FontWeight="SemiBold"/>
                                </StackPanel>
                            </Button>
                        </StackPanel>
                        <Grid>
                            <Grid.ColumnDefinitions>
                                <ColumnDefinition Width="*"/>
                                <ColumnDefinition Width="Auto"/>
                            </Grid.ColumnDefinitions>
                            <Grid MaxWidth="420" HorizontalAlignment="Stretch">
                                <TextBox x:Name="PathBox" Style="{StaticResource FluentTextBox}" Height="34" Padding="34,0,10,0"/>
                                <TextBlock FontFamily="{StaticResource IconFont}" Text="&#xE8B7;" FontSize="13" Foreground="#5B6270" Margin="12,0,0,0" HorizontalAlignment="Left" IsHitTestVisible="False"/>
                                <TextBlock x:Name="PathHint" Text="기본 위치에 설치 (경로를 넣으면 변경)" Foreground="#5B6270" Margin="35,0,0,0" IsHitTestVisible="False" TextTrimming="CharacterEllipsis"/>
                            </Grid>
                            <Button x:Name="BrowseBtn" Grid.Column="1" Content="찾아보기" Style="{StaticResource StandardBtn}" Margin="8,0,0,0" HorizontalAlignment="Left"/>
                        </Grid>
                    </DockPanel>
                </Border>

                <!-- 목록 머리글 -->
                <Grid x:Name="BrowseHeader" DockPanel.Dock="Top" Margin="17,0,35,8">
                    <Grid.ColumnDefinitions>
                        <ColumnDefinition Width="40"/>
                        <ColumnDefinition Width="50"/>
                        <ColumnDefinition Width="*"/>
                        <ColumnDefinition Width="210"/>
                        <ColumnDefinition Width="110"/>
                    </Grid.ColumnDefinitions>
                    <CheckBox x:Name="AllCheck" Style="{StaticResource FluentCheck}" HorizontalAlignment="Left" ToolTip="보이는 항목 모두 선택"/>
                    <TextBlock Grid.Column="1" Grid.ColumnSpan="2" Text="프로그램" Foreground="#5B6270" FontSize="12"/>
                    <TextBlock Grid.Column="3" Text="winget ID" Foreground="#5B6270" FontSize="12"/>
                    <TextBlock Grid.Column="4" Text="상태" Foreground="#5B6270" FontSize="12"/>
                </Grid>

                <Grid>
                <!-- 프로그램 목록 -->
                <Grid x:Name="BrowseView">
                    <!-- 스크롤바 자리를 항상 확보(Visible): 행 수와 관계없이 머리글 열이 행 열과 맞도록. 오른쪽 여백 = 스크롤바 12 + 패딩 6 -->
                    <ScrollViewer VerticalScrollBarVisibility="Visible" Padding="0,0,6,16">
                        <StackPanel x:Name="ListPanel"/>
                    </ScrollViewer>
                    <StackPanel x:Name="EmptyText" HorizontalAlignment="Center" VerticalAlignment="Center" Visibility="Collapsed">
                        <TextBlock FontFamily="{StaticResource IconFont}" Text="&#xE721;" FontSize="26" Foreground="#7A8BB8" HorizontalAlignment="Center"/>
                        <TextBlock Text="검색 결과가 없습니다" FontSize="13" FontWeight="SemiBold" HorizontalAlignment="Center" Margin="0,10,0,0"/>
                    </StackPanel>
                </Grid>

                <!-- 담은 항목: 순차 설치 안내 + 진행 + 항목별 단계 -->
                <DockPanel x:Name="CartView" Visibility="Collapsed">
                    <Border DockPanel.Dock="Top" Style="{StaticResource Panel}" Padding="16,12" Margin="0,0,18,12">
                        <Grid>
                            <Grid.ColumnDefinitions>
                                <ColumnDefinition Width="Auto"/><ColumnDefinition Width="*"/>
                            </Grid.ColumnDefinitions>
                            <TextBlock x:Name="CartIcon" FontFamily="{StaticResource IconFont}" Text="&#xE8CB;" FontSize="18" Foreground="#2557D6" Margin="0,1,12,0" VerticalAlignment="Top"/>
                            <StackPanel Grid.Column="1">
                                <TextBlock x:Name="CartHead" Text="순차 설치 · 담은 순서대로 한 번에 하나씩 설치합니다" FontSize="14" FontWeight="SemiBold" TextWrapping="Wrap"/>
                                <TextBlock x:Name="CartInfo" FontSize="12" Foreground="#5B6270" Margin="0,4,0,0" TextWrapping="Wrap"
                                           Text="실패하면 그 자리에서 바로 다시 시도하고, winget이 끝내 설치하지 못하면 이 도구가 공식 설치 파일을 직접 받아 설치합니다(대체 다운로드). 진행 상황은 항목마다 아래에 표시됩니다."/>
                                <ProgressBar x:Name="CartProg" Height="6" Margin="0,10,0,0" Minimum="0" Maximum="1" Value="0" Foreground="#2557D6" Background="#E3E6EB" BorderThickness="0" Visibility="Collapsed"/>
                            </StackPanel>
                        </Grid>
                    </Border>
                    <Grid>
                        <ScrollViewer x:Name="CartScroll" VerticalScrollBarVisibility="Visible" Padding="0,0,6,16">
                            <StackPanel x:Name="CartList"/>
                        </ScrollViewer>
                        <StackPanel x:Name="CartEmpty" HorizontalAlignment="Center" VerticalAlignment="Center">
                            <TextBlock FontFamily="{StaticResource IconFont}" Text="&#xE7BF;" FontSize="26" Foreground="#7A8BB8" HorizontalAlignment="Center"/>
                            <TextBlock Text="담은 항목이 없습니다" FontSize="13" FontWeight="SemiBold" HorizontalAlignment="Center" Margin="0,10,0,0"/>
                            <TextBlock Text="프로그램을 체크한 뒤 '선택 항목 담기'를 눌러 주세요." FontSize="12" Foreground="#5B6270" HorizontalAlignment="Center" Margin="0,4,0,0"/>
                        </StackPanel>
                    </Grid>
                </DockPanel>
                </Grid>
            </DockPanel>
        </Grid>
    </Grid>
</Window>
'@
[xml]$xaml = $XamlText.Replace('__UIFONT__', $UiFont)

# 창을 못 만들면 일반 오류로는 런처가 아무 표시 없이 끝나 버린다(2026-11-08 "안 열림" 원인).
# -> throw 로 바꿔 런처의 오류 창("설치 도구를 시작하지 못했습니다")에 XAML 줄 번호가 보이게 한다.
try { $window = [Windows.Markup.XamlReader]::Load((New-Object System.Xml.XmlNodeReader $xaml)) }
catch {
    $ex = $_.Exception; while ($ex.InnerException -and -not ($ex -is [Windows.Markup.XamlParseException])) { $ex = $ex.InnerException }
    throw "메인 창 XAML을 읽지 못했습니다: $($ex.Message)"
}
foreach ($n in 'NavPanel','WgDot','WgText','CatTitle','SearchBox','SearchHint','AllCheck','ListPanel','EmptyText',
               'PathBox','PathHint','BrowseBtn','SelText','LogBtn','InstallBtn','InstallText',
               'RootGrid','WinMin','WinMax','WinClose','BrandImg','BrandLogo','WgSub','WgUpdateBtn','WgUpdateText',
               'CommunityLink','VerText',
               'CartNav','CartInd','CartNm','CartBadge','CartCount','CatDesc','CartClearBtn','AddCartBtn','BrowseHeader','BrowseView',
               'CartView','CartIcon','CartHead','CartInfo','CartProg','CartScroll','CartList','CartEmpty') {
    Set-Variable -Name $n -Value $window.FindName($n) -Scope Script
}

# 버전 표시 + 커뮤니티 링크
$VerText.Text = "v$AppVersion"
$VerText.ToolTip = "필수 프로그램 설치 도구 버전 $AppVersion"
$CommunityLink.Add_RequestNavigate({ param($s, $ev)
    # 이 도구는 관리자 권한으로 돌므로 브라우저를 직접 띄우면 브라우저까지 관리자 권한이 된다.
    # explorer.exe 에 주소를 넘기면 일반 사용자 권한의 기본 브라우저로 열린다.
    try { Start-Process -FilePath 'explorer.exe' -ArgumentList $ev.Uri.AbsoluteUri } catch { try { Start-Process $ev.Uri.AbsoluteUri } catch { } }
    $ev.Handled = $true
})

# 제목 표시줄 (WindowStyle=None + WindowChrome, ArtisanOS와 같은 방식)
$WinMin.Add_Click({ $window.WindowState = 'Minimized' })
$WinMax.Add_Click({ $window.WindowState = if ($window.WindowState -eq 'Maximized') { 'Normal' } else { 'Maximized' } })
$WinClose.Add_Click({ $window.Close() })   # 설치 중 닫기 확인은 Add_Closing 에서 처리
$window.Add_StateChanged({
    $max = ($window.WindowState -eq 'Maximized')
    # 테두리 없는 창은 최대화하면 화면 밖으로 몇 픽셀 넘침 -> 여백으로 보정
    $RootGrid.Margin = if ($max) { [Windows.Thickness]::new(7) } else { [Windows.Thickness]::new(0) }
    $WinMax.Content = if ($max) { [string][char]0xE923 } else { [string][char]0xE922 }
    $WinMax.ToolTip = if ($max) { '이전 크기로' } else { '최대화' }
})

# 브랜드 로고 (ArtisanOS 'A' 마크: icons\_artisan.png 가 빌드 때 내장됨)
$BrandBmp = $null
try {
    $b64 = $EmbeddedIcons['_artisan']
    $brandFile = Join-Path $CustomIconDir '_artisan.png'
    $BrandBmp = New-Object Windows.Media.Imaging.BitmapImage
    $BrandBmp.BeginInit(); $BrandBmp.CacheOption = [Windows.Media.Imaging.BitmapCacheOption]::OnLoad
    if (Test-Path $brandFile) { $BrandBmp.UriSource = New-Object Uri($brandFile) }
    elseif ($b64) { $BrandBmp.StreamSource = New-Object IO.MemoryStream (, [Convert]::FromBase64String($b64)) }
    else { throw 'no brand image' }
    $BrandBmp.EndInit(); $BrandBmp.Freeze()
    $BrandImg.Source = $BrandBmp; $BrandLogo.Source = $BrandBmp; $window.Icon = $BrandBmp
} catch { $BrandBmp = $null }

# 창 아이콘을 EXE 아이콘으로 (브랜드 이미지를 못 읽었을 때)
if (-not $BrandBmp -and $env:PI_EXE_PATH -and (Test-Path $env:PI_EXE_PATH)) {
    try {
        $exeIcon = [System.Drawing.Icon]::ExtractAssociatedIcon($env:PI_EXE_PATH)
        $window.Icon = [System.Windows.Interop.Imaging]::CreateBitmapSourceFromHIcon($exeIcon.Handle,
            [Windows.Int32Rect]::Empty, [Windows.Media.Imaging.BitmapSizeOptions]::FromEmptyOptions())
    } catch { }
}

function Show-Msg($text, $title = '알림', $buttons = 'OK', $icon = 'None') {
    return [System.Windows.MessageBox]::Show($window, $text, $title, $buttons, $icon)
}

$BC = New-Object Windows.Media.BrushConverter
function Brush($hex) { if ($hex) { $BC.ConvertFromString($hex) } else { [Windows.Media.Brushes]::Transparent } }

# ───────────────────────────── 로그 ─────────────────────────────
function Write-Log($text) {
    $stamped = "$([DateTime]::Now.ToString('HH:mm:ss')) $text"
    try { Add-Content -Path $LogFilePath -Value $stamped -Encoding UTF8 } catch { }
}

# ───────────────────────────── 상태 표시 ─────────────────────────────
# 종류 = 배경색, 글자색, 기본 문구
# 색: ArtisanOS 토큰 (성공 #ECF7EF/#1E6B3A, 진행 #EAF0FC/#1E47B3, 주의 #FEF3E7/#B54708, 오류 #FDECEC/#B42318, 중립 #F0F1F4/#4A5160)
$StatusStyles = @{
    checking   = @($null,      '#8A909C', '확인 중…')
    none       = @($null,      '#5B6270', '미설치')
    installed  = @('#ECF7EF',  '#1E6B3A', '설치됨')
    carted     = @('#EAF0FC',  '#1E47B3', '담김')
    queued     = @('#F0F1F4',  '#4A5160', '대기 중')
    installing = @('#EAF0FC',  '#1E47B3', '설치 중…')
    verifying  = @('#EAF0FC',  '#1E47B3', '확인 중…')
    done       = @('#ECF7EF',  '#1E6B3A', '완료')
    failed     = @('#FDECEC',  '#B42318', '실패')
    warn       = @('#FEF3E7',  '#B54708', '확인 필요')
    skipped    = @('#FEF3E7',  '#B54708', '건너뜀')
}
function Set-Status($e, $kind, $text, $tip) {
    $s = $StatusStyles[$kind]
    $e.Status = $kind
    $e.Pill.Background = Brush $s[0]
    # 배경이 없는 상태(미설치·확인 중)도 같은 안쪽 여백을 둬야 '설치됨'과 글자 시작 위치가 맞는다
    $e.Pill.Padding = [Windows.Thickness]::new(10, 0, 10, 0)
    $e.St.Foreground = Brush $s[1]
    $e.St.FontWeight = if ($s[0]) { [Windows.FontWeights]::SemiBold } else { [Windows.FontWeights]::Normal }
    $e.St.Text = if ($text) { $text } else { $s[2] }
    $e.Pill.ToolTip = $tip
    # 담은 항목 화면의 같은 배지도 똑같이
    if ($e.CartPill) {
        $e.CartPill.Background = $e.Pill.Background
        $e.CartPill.Padding = $e.Pill.Padding
        $e.CartSt.Foreground = $e.St.Foreground
        $e.CartSt.FontWeight = $e.St.FontWeight
        $e.CartSt.Text = $e.St.Text
        $e.CartPill.ToolTip = $tip
    }
    # 이미 설치된 항목은 체크할 수 없게 (전체 선택에도 포함되지 않음)
    if ($kind -eq 'installed') { $e.Cb.IsChecked = $false; $e.Cb.IsEnabled = $false }
    elseif ($e.Cb -and -not $e.Cb.IsEnabled -and -not $script:Busy) { $e.Cb.IsEnabled = $true }
}
function Set-WgCard($kind, $text) {
    $color = @{ ok = '#1E6B3A'; busy = '#2557D6'; warn = '#B54708'; error = '#B42318' }[$kind]
    $WgDot.Fill = Brush $color
    $WgText.Text = $text
}

# ───────────────────────────── 목록 만들기 ─────────────────────────────
$Tiles = @('#3A6EA5', '#7A4E9A', '#2E7D6B', '#B0582C', '#5A6472', '#A13D5B', '#3F7F3A', '#8A6A1F')
$script:Entries = New-Object System.Collections.Generic.List[object]
$script:NavItems = New-Object System.Collections.Generic.List[object]
$script:CurrentCat = '전체'
$XNS = 'xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"'
function X($s) { [Security.SecurityElement]::Escape([string]$s) }

# 카테고리 기호 (Segoe Fluent Icons, ArtisanOS 사이드바와 같은 방식). 없는 카테고리는 기본 기호
$CatGlyph = @{
    '전체' = 0xE71D; '브라우저' = 0xE774; '메신저&협업' = 0xE8BD; '동영상 플레이어' = 0xE714; '음악 플레이어' = 0xE8D6
    '뷰어' = 0xEB9F; '압축 프로그램' = 0xE7B8; '유틸리티' = 0xE90F; '게임런처' = 0xE7FC; 'AI Tool' = 0xE945; '개발' = 0xE943
}
function New-NavButton($name, $count) {
    # 디자인: ArtisanOS 사이드바 (조각은 따로 읽히므로 StaticResource 대신 DynamicResource 사용)
    #   ind = 카테고리 기호(선택 시 강조색), nm = 이름
    $g = if ($CatGlyph.ContainsKey($name)) { $CatGlyph[$name] } else { 0xE8FD }
    $btn = [Windows.Markup.XamlReader]::Parse(@"
<Button $XNS Style="{DynamicResource NavButton}">
  <Grid>
    <Grid.ColumnDefinitions>
      <ColumnDefinition Width="Auto"/><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/>
    </Grid.ColumnDefinitions>
    <TextBlock x:Name="ind" FontFamily="{DynamicResource IconFont}" Text="&#x$('{0:X4}' -f $g);" FontSize="15" Width="18" Margin="0,0,10,0"/>
    <TextBlock x:Name="nm" Grid.Column="1" Text="$(X $name)" FontSize="13" TextTrimming="CharacterEllipsis"/>
    <TextBlock Grid.Column="2" Text="$count" FontSize="12" Foreground="{DynamicResource TextSecondary}" Margin="8,0,0,0"/>
  </Grid>
</Button>
"@)
    $btn.Tag = $name
    $btn.Add_Click({ param($s, $ev) Set-Category $s.Tag })
    $NavPanel.Children.Add($btn) | Out-Null
    $script:NavItems.Add([PSCustomObject]@{ Cat = $name; Btn = $btn; Ind = $btn.FindName('ind'); Nm = $btn.FindName('nm') })
}

function New-Row($app, $cat, $index) {
    $initial = ([string]$app.Name).Substring(0, 1).ToUpper()
    $idText  = if ($app.Portable) { '(직접 받기 · 포터블)' }
               elseif ($app.Source -eq 'msstore') { "$($app.Id) (Store)" }
               elseif ($app.DirectOnly) { '공식 사이트 직접 설치' }
               elseif ($app.Id) { $app.Id } else { '(로컬 설치파일)' }
    # 디자인: ArtisanOS 선택 카드 (조각은 따로 읽히므로 StaticResource 대신 DynamicResource 사용)
    #   열 너비는 메인 창의 목록 머리글(40/50/*/210/110)과 맞춰야 함
    $row = [Windows.Markup.XamlReader]::Parse(@"
<Border $XNS Style="{DynamicResource RowStyle}" Height="60" Padding="16,0" Cursor="Hand">
  <Grid>
    <Grid.ColumnDefinitions>
      <ColumnDefinition Width="40"/><ColumnDefinition Width="50"/><ColumnDefinition Width="*"/>
      <ColumnDefinition Width="210"/><ColumnDefinition Width="110"/>
    </Grid.ColumnDefinitions>
    <CheckBox x:Name="cb" Grid.Column="0" Style="{DynamicResource FluentCheck}" HorizontalAlignment="Left" VerticalAlignment="Center"/>
    <Grid Grid.Column="1">
      <Border x:Name="tile" Width="36" Height="36" Background="#F0F1F4" CornerRadius="8" HorizontalAlignment="Left">
        <TextBlock Text="$(X $initial)" FontSize="15" FontWeight="Bold" Foreground="#5B6270" HorizontalAlignment="Center" VerticalAlignment="Center"/>
      </Border>
      <Image x:Name="img" Width="32" Height="32" HorizontalAlignment="Left" Margin="2,0,0,0" RenderOptions.BitmapScalingMode="HighQuality" Visibility="Collapsed"/>
    </Grid>
    <StackPanel Grid.Column="2" VerticalAlignment="Center" Margin="8,0,16,0">
      <TextBlock Text="$(X $app.Name)" FontSize="14" FontWeight="SemiBold" TextTrimming="CharacterEllipsis"/>
      <TextBlock Text="$(X $cat)" FontSize="12" Foreground="{DynamicResource TextSecondary}" Margin="0,2,0,0"/>
    </StackPanel>
    <TextBlock Grid.Column="3" Text="$(X $idText)" $(if ($app.DirectOnly) { '' } else { 'FontFamily="Cascadia Mono, Consolas, Malgun Gothic"' }) FontSize="12" Foreground="{DynamicResource TextSecondary}" VerticalAlignment="Center" TextTrimming="CharacterEllipsis" Margin="0,0,12,0"/>
    <Border x:Name="pill" Grid.Column="4" Height="24" CornerRadius="6" Padding="10,0" HorizontalAlignment="Left" VerticalAlignment="Center">
      <TextBlock x:Name="st" FontSize="12" FontWeight="SemiBold" VerticalAlignment="Center"/>
    </Border>
  </Grid>
</Border>
"@)
    $e = [PSCustomObject]@{
        App = $app; Category = $cat; Row = $row
        Cb = $row.FindName('cb'); Tile = $row.FindName('tile'); Img = $row.FindName('img')
        Pill = $row.FindName('pill'); St = $row.FindName('st')
        Status = ''; HasIcon = $false; Retried = $false; IgnoreHash = $false; SkipDeps = $false; DirectFailed = $false
        UseFallback = $false; FallbackTried = $false; Homepage = $null
        InCart = $false; CartRow = $null; CartNum = $null; CartStage = $null; CartPill = $null; CartSt = $null; CartRm = $null
    }
    if ($app.Note) { $row.ToolTip = $app.Note }
    $row.Tag = $e
    # 줄 아무 데나 눌러도 체크
    $row.Add_MouseLeftButtonUp({ param($s, $ev)
        $en = $s.Tag
        if (-not $en.Cb.IsEnabled -or $en.Cb.IsMouseOver) { return }
        $en.Cb.IsChecked = -not [bool]$en.Cb.IsChecked
    })
    $e.Cb.Add_Checked({ Update-Selection })
    $e.Cb.Add_Unchecked({ Update-Selection })
    Set-Status $e 'checking'
    $ListPanel.Children.Add($row) | Out-Null
    $script:Entries.Add($e)
}

$total = 0; foreach ($c in $Categories.Keys) { $total += $Categories[$c].Count }
New-NavButton '전체' $total
$i = 0
foreach ($cat in $Categories.Keys) {
    New-NavButton $cat $Categories[$cat].Count
    foreach ($app in $Categories[$cat]) { New-Row $app $cat $i; $i++ }
}

# ───────────────────────────── 선택 / 필터 ─────────────────────────────
$script:SyncingAll = $false
function Get-Visible { @($script:Entries | Where-Object { $_.Row.Visibility -eq 'Visible' }) }

function Update-Selection {
    if ($script:Phase -ne 'idle') { return }
    $n = @($script:Entries | Where-Object { $_.Cb.IsChecked }).Count
    $SelText.Text = "${n}개 선택됨"
    $vis = Get-Visible
    $script:SyncingAll = $true
    $AllCheck.IsChecked = ($vis.Count -gt 0 -and @($vis | Where-Object { -not $_.Cb.IsChecked }).Count -eq 0)
    $script:SyncingAll = $false
}

function Apply-Filter {
    $q = $SearchBox.Text.Trim()
    $shown = 0
    foreach ($e in $script:Entries) {
        $okCat = ($script:CurrentCat -eq '전체') -or ($e.Category -eq $script:CurrentCat)
        $okQ = (-not $q) -or ($e.App.Name.IndexOf($q, [StringComparison]::OrdinalIgnoreCase) -ge 0) -or
               ($e.App.Id -and $e.App.Id.IndexOf($q, [StringComparison]::OrdinalIgnoreCase) -ge 0)
        if ($okCat -and $okQ) { $e.Row.Visibility = 'Visible'; $shown++ } else { $e.Row.Visibility = 'Collapsed' }
    }
    $EmptyText.Visibility = if ($shown -eq 0) { 'Visible' } else { 'Collapsed' }
    Update-Selection
}

function Set-NavLook($btn, $ind, $nm, $on) {
    # ArtisanOS 사이드바: 선택 = 흰 바탕 + 테두리 + 진한 글자, 기호는 강조색
    $btn.Background  = if ($on) { Brush '#FFFFFF' } else { [Windows.Media.Brushes]::Transparent }
    $btn.BorderBrush = if ($on) { Brush '#E3E6EB' } else { [Windows.Media.Brushes]::Transparent }
    $btn.Foreground  = if ($on) { Brush '#1C1F26' } else { Brush '#4A5160' }
    $ind.Foreground  = if ($on) { Brush '#2557D6' } else { Brush '#5B6270' }
    $nm.FontWeight   = if ($on) { [Windows.FontWeights]::SemiBold } else { [Windows.FontWeights]::Medium }
}

# 화면 전환: 프로그램 목록(카테고리) <-> 담은 항목
$script:CartMode = $false
function Show-View([bool]$cart) {
    $script:CartMode = $cart
    $b = if ($cart) { 'Collapsed' } else { 'Visible' }
    $c = if ($cart) { 'Visible' } else { 'Collapsed' }
    $BrowseView.Visibility = $b; $BrowseHeader.Visibility = $b; $AddCartBtn.Visibility = $b; $SelText.Visibility = $b
    $CartView.Visibility = $c; $InstallBtn.Visibility = $c; $CartClearBtn.Visibility = $c
    $LogBtn.Margin = if ($cart) { [Windows.Thickness]::new(8, 0, 8, 0) } else { [Windows.Thickness]::new(0, 0, 8, 0) }
    Set-NavLook $CartNav $CartInd $CartNm $cart
    if ($cart) {
        foreach ($n in $script:NavItems) { Set-NavLook $n.Btn $n.Ind $n.Nm $false }
        $CatTitle.Text = '담은 항목'
        $CatDesc.Text = "담은 순서대로 한 번에 하나씩 설치합니다. 목록에서 빼려면 오른쪽 ✕ 를 누르세요."
        Update-CartUi
    } else {
        $CatDesc.Text = "설치할 프로그램을 체크하고 '선택 항목 담기'를 누르세요. 담은 항목에서 한 번에 설치합니다."
    }
}

function Set-Category($name) {
    $script:CurrentCat = $name
    Show-View $false
    foreach ($n in $script:NavItems) { Set-NavLook $n.Btn $n.Ind $n.Nm ($n.Cat -eq $name) }
    $CatTitle.Text = if ($name -eq '전체') { '전체 프로그램' } else { $name }
    Apply-Filter
}

# ───────────────────────────── 담은 항목 (설치 바구니) ─────────────────────────────
$script:Cart = New-Object System.Collections.Generic.List[object]

# 항목별 진행 단계 문구 (담은 항목 화면의 이름 아래 줄)
function Set-Stage($e, $text, $color = '#5B6270') {
    if (-not $e.CartStage) { return }
    $e.CartStage.Text = $text
    $e.CartStage.Foreground = Brush $color
}
# 배지 글자만 바꾸기 (경과 시간 등) - 목록·담은 항목 둘 다
function Set-PillText($e, $text) {
    $e.St.Text = $text
    if ($e.CartSt) { $e.CartSt.Text = $text }
}

function Update-CartUi {
    $n = $script:Cart.Count
    $CartCount.Text = "$n"
    $CartBadge.Visibility = if ($n -gt 0) { 'Visible' } else { 'Collapsed' }
    $CartEmpty.Visibility = if ($n -gt 0) { 'Collapsed' } else { 'Visible' }
    $i = 1; foreach ($e in $script:Cart) { $e.CartNum.Text = "$i"; $i++ }
    if ($script:Phase -eq 'idle') {
        $pending = @($script:Cart | Where-Object { $_.Status -notin @('done', 'installed') }).Count
        $InstallBtn.IsEnabled = ($pending -gt 0)
        $InstallText.Text = if ($pending -gt 0) { "순차 설치 시작 (${pending}개)" } else { '순차 설치 시작' }
        $CartClearBtn.IsEnabled = ($n -gt 0)
    }
}

function Add-ToCart($e) {
    if ($e.InCart) { return }
    $initial = ([string]$e.App.Name).Substring(0, 1).ToUpper()
    # 디자인: 목록 행과 같은 카드. 열 = 순서 / 아이콘 / 이름+진행 단계 / 상태 / 빼기
    $row = [Windows.Markup.XamlReader]::Parse(@"
<Border $XNS Style="{DynamicResource RowStyle}" MinHeight="64" Padding="16,10,8,10">
  <Grid>
    <Grid.ColumnDefinitions>
      <ColumnDefinition Width="34"/><ColumnDefinition Width="50"/><ColumnDefinition Width="*"/>
      <ColumnDefinition Width="120"/><ColumnDefinition Width="40"/>
    </Grid.ColumnDefinitions>
    <TextBlock x:Name="num" FontSize="13" FontWeight="SemiBold" Foreground="{DynamicResource TextSecondary}" VerticalAlignment="Center"/>
    <Grid Grid.Column="1" VerticalAlignment="Center">
      <Border x:Name="tile" Width="36" Height="36" Background="#F0F1F4" CornerRadius="8" HorizontalAlignment="Left">
        <TextBlock Text="$(X $initial)" FontSize="15" FontWeight="Bold" Foreground="#5B6270" HorizontalAlignment="Center" VerticalAlignment="Center"/>
      </Border>
      <Image x:Name="img" Width="32" Height="32" HorizontalAlignment="Left" Margin="2,0,0,0" RenderOptions.BitmapScalingMode="HighQuality" Visibility="Collapsed"/>
    </Grid>
    <StackPanel Grid.Column="2" VerticalAlignment="Center" Margin="8,0,16,0">
      <TextBlock Text="$(X $e.App.Name)" FontSize="14" FontWeight="SemiBold" TextTrimming="CharacterEllipsis"/>
      <TextBlock x:Name="stage" FontSize="12" Foreground="#5B6270" Margin="0,3,0,0" TextWrapping="Wrap"/>
    </StackPanel>
    <Border x:Name="pill" Grid.Column="3" Height="24" CornerRadius="6" Padding="10,0" HorizontalAlignment="Left" VerticalAlignment="Center">
      <TextBlock x:Name="st" FontSize="12" FontWeight="SemiBold" VerticalAlignment="Center"/>
    </Border>
    <Button x:Name="rm" Grid.Column="4" Style="{DynamicResource ChromeBtn}" Width="32" Height="32" Content="&#xE711;" FontSize="11" ToolTip="목록에서 빼기" AutomationProperties.Name="목록에서 빼기" VerticalAlignment="Center"/>
  </Grid>
</Border>
"@)
    $e.CartRow = $row; $e.CartNum = $row.FindName('num'); $e.CartStage = $row.FindName('stage')
    $e.CartPill = $row.FindName('pill'); $e.CartSt = $row.FindName('st'); $e.CartRm = $row.FindName('rm')
    if ($e.HasIcon -and $e.Img.Source) { $ci = $row.FindName('img'); $ci.Source = $e.Img.Source; $ci.Visibility = 'Visible'; $row.FindName('tile').Visibility = 'Collapsed' }
    $e.CartRm.Tag = $e
    $e.CartRm.Add_Click({ param($s, $ev) Remove-FromCart $s.Tag })
    $e.InCart = $true
    $script:Cart.Add($e)
    $CartList.Children.Add($row) | Out-Null
    Set-Status $e 'carted'
    Set-Stage $e '설치 대기'
}

function Remove-FromCart($e) {
    if ($script:Phase -ne 'idle' -or -not $e.InCart) { return }
    $CartList.Children.Remove($e.CartRow)
    [void]$script:Cart.Remove($e)
    $e.InCart = $false; $e.CartRow = $null; $e.CartPill = $null; $e.CartSt = $null; $e.CartStage = $null; $e.CartNum = $null
    # 목록 쪽 배지: 설치를 마친 것은 '설치됨', 나머지는 '미설치'로 되돌린다
    if ($e.Status -eq 'done') { Set-Status $e 'installed' } elseif ($e.Status -ne 'installed') { Set-Status $e 'none' }
    Update-CartUi
}

$CartNav.Add_Click({ Show-View $true })
$AddCartBtn.Add_Click({
    $sel = @($script:Entries | Where-Object { $_.Cb.IsChecked })
    if ($sel.Count -eq 0) { Show-Msg "담을 프로그램을 체크해 주세요." | Out-Null; return }
    $added = 0
    foreach ($e in $sel) { if (-not $e.InCart) { Add-ToCart $e; $added++ }; $e.Cb.IsChecked = $false }
    Update-CartUi
    Update-Selection
    $SelText.Text = "${added}개를 담았습니다 · 왼쪽 '담은 항목'에서 설치"
})
$CartClearBtn.Add_Click({
    if ($script:Phase -ne 'idle') { return }
    foreach ($e in @($script:Cart)) { Remove-FromCart $e }
    $CartHead.Text = '순차 설치 · 담은 순서대로 한 번에 하나씩 설치합니다'
    $CartProg.Visibility = 'Collapsed'
})

$AllCheck.Add_Click({
    if ($script:SyncingAll) { return }
    $want = [bool]$AllCheck.IsChecked
    foreach ($e in (Get-Visible)) { $e.Cb.IsChecked = ($want -and $e.Status -ne 'installed') }
})
$SearchBox.Add_TextChanged({
    $SearchHint.Visibility = if ($SearchBox.Text) { 'Collapsed' } else { 'Visible' }
    if ($script:CartMode -and $SearchBox.Text) { Set-Category $script:CurrentCat; return }   # 검색하면 목록 화면으로
    Apply-Filter
})
$PathBox.Add_TextChanged({ $PathHint.Visibility = if ($PathBox.Text) { 'Collapsed' } else { 'Visible' } })
$BrowseBtn.Add_Click({
    $fbd = New-Object System.Windows.Forms.FolderBrowserDialog
    if ($fbd.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) { $PathBox.Text = $fbd.SelectedPath }
})
$LogBtn.Add_Click({
    if (Test-Path $LogFilePath) { Start-Process notepad.exe -ArgumentList "`"$LogFilePath`"" }
    else { Show-Msg "아직 로그가 없습니다." "로그" | Out-Null }
})

# ───────────────────────────── 아이콘 ─────────────────────────────
# 우선순위: ① EXE 옆 icons 폴더 ② 내장 아이콘 ③ 이 PC에 설치된 프로그램 자체 아이콘 ④ 글자 타일
function Show-Icon($e, $source) {
    if (-not $source) { return $false }
    try {
        $e.Img.Source = $source
        $e.Img.Visibility = 'Visible'
        $e.Tile.Visibility = 'Collapsed'
        $e.HasIcon = $true
        return $true
    } catch { return $false }
}
function Get-BitmapFromFile($path) {
    try {
        $bmp = New-Object Windows.Media.Imaging.BitmapImage
        $bmp.BeginInit()
        $bmp.CacheOption = [Windows.Media.Imaging.BitmapCacheOption]::OnLoad
        $bmp.UriSource = New-Object Uri($path)
        $bmp.EndInit(); $bmp.Freeze()
        return $bmp
    } catch { return $null }
}
function Get-BitmapFromBase64($b64) {
    try {
        $bmp = New-Object Windows.Media.Imaging.BitmapImage
        $bmp.BeginInit()
        $bmp.CacheOption = [Windows.Media.Imaging.BitmapCacheOption]::OnLoad
        $bmp.StreamSource = New-Object IO.MemoryStream (, [Convert]::FromBase64String($b64))
        $bmp.EndInit(); $bmp.Freeze()
        return $bmp
    } catch { return $null }
}
# 설치된 프로그램의 EXE/ICO에서 아이콘 추출 (레지스트리 DisplayIcon 값: "C:\...\app.exe,0" 형태)
function Get-BitmapFromDisplayIcon($displayIcon) {
    if (-not $displayIcon) { return $null }
    $path = ($displayIcon -replace ',\s*-?\d+\s*$', '').Trim().Trim('"')
    $path = [Environment]::ExpandEnvironmentVariables($path)
    if (-not (Test-Path -LiteralPath $path)) { return $null }
    if ($path -match '\.(ico|png)$') { return Get-BitmapFromFile $path }
    try {
        $ico = [System.Drawing.Icon]::ExtractAssociatedIcon($path)
        $src = [System.Windows.Interop.Imaging]::CreateBitmapSourceFromHIcon($ico.Handle,
            [Windows.Int32Rect]::Empty, [Windows.Media.Imaging.BitmapSizeOptions]::FromEmptyOptions())
        $src.Freeze()
        return $src
    } catch { return $null }
}

function Start-IconLoad {
    foreach ($e in $script:Entries) {
        $key = if ($e.App.Id) { $e.App.Id } else { $e.App.Name }
        $safe = $key -replace '[^\w\.\-\+]', '_'
        $custom = @('png', 'ico') | ForEach-Object { Join-Path $CustomIconDir "$safe.$_" } | Where-Object { Test-Path $_ } | Select-Object -First 1
        if ($custom -and (Show-Icon $e (Get-BitmapFromFile $custom))) { continue }
        if ($EmbeddedIcons.ContainsKey($safe)) { [void](Show-Icon $e (Get-BitmapFromBase64 $EmbeddedIcons[$safe])) }
    }
}

# ───────────────────────────── 프로세스 ─────────────────────────────
function Start-Hidden($file, $arguments, [switch]$Redirect) {
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    if ($Redirect) { $psi.RedirectStandardOutput = $true }
    $psi.FileName = $file
    $psi.Arguments = $arguments
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $true
    $psi.WindowStyle = [System.Diagnostics.ProcessWindowStyle]::Hidden
    return [System.Diagnostics.Process]::Start($psi)
}

# 포터블 프로그램이 복사될 위치
function Get-PortableTarget($app) {
    $base = $PathBox.Text.Trim()
    if ($base) { return Join-Path $base $app.Portable }
    return Join-Path $env:LOCALAPPDATA "Programs\$($app.Portable)"
}
function Find-PortableExe($folder, $exeName) {
    if (-not (Test-Path $folder)) { return $null }
    $arch = if ([Environment]::Is64BitOperatingSystem) { 'x64' } else { 'x86' }
    foreach ($c in @((Join-Path $folder "$arch\$exeName"), (Join-Path $folder $exeName))) { if (Test-Path $c) { return $c } }
    $f = Get-ChildItem -Path $folder -Filter $exeName -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($f) { return $f.FullName }
    return $null
}

# 설치 여부 확인 1단계: Windows '설치된 앱' 목록(레지스트리 Uninstall 키) + Store 앱 + 포터블 직접 확인
#   winget은 직접 설치 안 한 프로그램(특히 디스코드처럼 사용자 폴더에 깔리는 것)을
#   자기 목록과 짝짓지 못해서 export에서 빠뜨리는 경우가 많음 -> 이걸 먼저 본다.
#   찾은 프로그램이 내장 아이콘이 없으면 그 프로그램 자체 아이콘을 뽑아서 쓴다.
# '설치된 앱' 목록 읽기
#   - Get-ItemProperty 와일드카드는 값이 깨진 키가 하나만 있어도 그 위치 전체를 못 읽는 경우가 있어서
#     .NET으로 키 하나씩 따로 읽는다 (깨진 키만 건너뜀).
#   - 32/64비트 보기를 직접 지정해서, PowerShell이 몇 비트로 실행되든 양쪽 다 본다.
function Get-InstalledApps {
    $list = New-Object System.Collections.Generic.List[object]
    $sub = 'Software\Microsoft\Windows\CurrentVersion\Uninstall'
    $targets = @(
        @([Microsoft.Win32.RegistryHive]::LocalMachine, [Microsoft.Win32.RegistryView]::Registry64),
        @([Microsoft.Win32.RegistryHive]::LocalMachine, [Microsoft.Win32.RegistryView]::Registry32),
        @([Microsoft.Win32.RegistryHive]::CurrentUser,  [Microsoft.Win32.RegistryView]::Registry64),
        @([Microsoft.Win32.RegistryHive]::CurrentUser,  [Microsoft.Win32.RegistryView]::Registry32)
    )
    foreach ($t in $targets) {
        try {
            $base = [Microsoft.Win32.RegistryKey]::OpenBaseKey($t[0], $t[1])
            $root = $base.OpenSubKey($sub)
            if (-not $root) { continue }
            foreach ($name in $root.GetSubKeyNames()) {
                try {
                    $k = $root.OpenSubKey($name)
                    if (-not $k) { continue }
                    $dn = [string]$k.GetValue('DisplayName')
                    if ($dn -and $dn.Trim()) {
                        $list.Add([PSCustomObject]@{ Name = $dn.Trim(); Icon = [string]$k.GetValue('DisplayIcon'); Publisher = [string]$k.GetValue('Publisher') })
                    }
                    $k.Close()
                } catch { }
            }
            $root.Close()
        } catch { }
    }
    return $list
}

# Store/MSIX 앱 목록.
#   Get-AppxPackage 는 이 프로그램처럼 PowerShell 을 EXE 안에서 돌리면 조용히 실패하는 경우가 있어
#   (Codex/Claude 가 설치돼 있어도 '미설치'로 보였던 원인) 현재 사용자의 패키지 저장소 레지스트리를 직접 읽는다.
function Get-AppxList {
    $list = New-Object System.Collections.Generic.List[object]
    try {
        $root = [Microsoft.Win32.Registry]::CurrentUser.OpenSubKey('Software\Classes\Local Settings\Software\Microsoft\Windows\CurrentVersion\AppModel\Repository\Packages')
        if ($root) {
            foreach ($full in $root.GetSubKeyNames()) {
                $loc = ''
                try { $k = $root.OpenSubKey($full); if ($k) { $loc = [string]$k.GetValue('PackageRootFolder'); $k.Close() } } catch { }
                $list.Add([PSCustomObject]@{ Name = ($full -split '_')[0]; FullName = $full; InstallLocation = $loc })
            }
            $root.Close()
        }
    } catch { }
    if ($list.Count -eq 0) {
        try { foreach ($p in @(Get-AppxPackage -ErrorAction SilentlyContinue)) { $list.Add([PSCustomObject]@{ Name = $p.Name; FullName = $p.PackageFullName; InstallLocation = $p.InstallLocation }) } } catch { }
    }
    return $list
}

function Test-AppRegistered($app) {
    foreach ($pp in @($app.Paths)) { if ($pp -and (Test-Path ([Environment]::ExpandEnvironmentVariables($pp)))) { return $true } }
    if ($app.Appx -and @(Get-AppxList | Where-Object { $_.Name -match $app.Appx }).Count -gt 0) { return $true }
    if (-not $app.Match) { return $false }
    foreach ($a in (Get-InstalledApps)) {
        if ($a.Name -match $app.Match -and (-not $app.Publisher -or $a.Publisher -match $app.Publisher)) { return $true }
    }
    return $false
}

function Test-InstalledFromRegistry {
    $apps = Get-InstalledApps
    $appx = @()
    if (@($script:Entries | Where-Object { $_.App.Appx }).Count -gt 0) { $appx = @(Get-AppxList) }
    foreach ($e in $script:Entries) {
        if ($e.Status -ne 'checking') { continue }
        if ($e.App.Match) {
            foreach ($a in $apps) {
                if ($a.Name -match $e.App.Match -and (-not $e.App.Publisher -or $a.Publisher -match $e.App.Publisher)) {
                    Set-Status $e 'installed' $null "설치된 앱: $($a.Name)"
                    if (-not $e.HasIcon) { [void](Show-Icon $e (Get-BitmapFromDisplayIcon $a.Icon)) }
                    break
                }
            }
        }
        # 설치 목록 이름이 한글 등으로 달라 못 찾는 경우 대비: 실제 설치 파일 경로로 확인
        if ($e.Status -eq 'checking' -and $e.App.Paths) {
            foreach ($pp in $e.App.Paths) {
                $x = [Environment]::ExpandEnvironmentVariables($pp)
                if (Test-Path $x) {
                    Set-Status $e 'installed' $null "설치 파일: $x"
                    if (-not $e.HasIcon) { [void](Show-Icon $e (Get-BitmapFromDisplayIcon $x)) }
                    break
                }
            }
        }
        if ($e.Status -eq 'checking' -and $e.App.Appx) {
            $pkg = $appx | Where-Object { $_.Name -match $e.App.Appx } | Select-Object -First 1
            if ($pkg) {
                Set-Status $e 'installed' $null "Store 앱: $($pkg.Name)"
                if (-not $e.HasIcon) {
                    try {
                        $logo = Get-ChildItem -Path $pkg.InstallLocation -Recurse -Include '*Logo*.png', '*Square44*.png', '*StoreLogo*.png' -ErrorAction SilentlyContinue |
                                Sort-Object Length -Descending | Select-Object -First 1
                        if ($logo) { [void](Show-Icon $e (Get-BitmapFromFile $logo.FullName)) }
                    } catch { }
                }
            }
        }
        if ($e.App.Portable) {
            $exe = Find-PortableExe (Get-PortableTarget $e.App) $e.App.Exe
            if ($exe) {
                Set-Status $e 'installed' $null $exe
                if (-not $e.HasIcon) { [void](Show-Icon $e (Get-BitmapFromDisplayIcon $exe)) }
            } else {
                Set-Status $e 'none'
                # 설치 전이라도 EXE 옆에 받아둔 폴더가 있으면 그 아이콘 사용
                $src = Find-PortableExe (Join-Path $ScriptDir $e.App.Portable) $e.App.Exe
                if ($src -and -not $e.HasIcon) { [void](Show-Icon $e (Get-BitmapFromDisplayIcon $src)) }
            }
        }
    }
    # 레지스트리/Store/포터블로도 못 찾은 건 여기서 '미설치'로 확정 (winget 단계를 기다리지 않음)
    foreach ($e in $script:Entries) { if ($e.Status -eq 'checking') { Set-Status $e 'none' } }
}

# 설치 여부 확인 2단계(보조): winget 확인 + winget이 아는 목록으로 1단계에서 놓친 것만 보충
#   - 카드는 winget 자체의 유무를 보여준다 (설치 기능이 winget을 쓰므로 이게 핵심 정보).
#   - 1단계(레지스트리)가 이미 모든 항목을 '설치됨/미설치'로 확정해 두므로 export가 실패해도 조용히 넘어간다.
#   - 전부 백그라운드로 돌리고 타이머로 확인해서 화면이 멈추지 않게 한다.
$script:HasWinget   = $null     # $null = 아직 모름(막지 않음), $true/$false = 확인됨
$script:WingetExtra = ''        # winget 1.4 이상이면 ' --disable-interactivity' (숨은 창에서 질문하며 멈추는 것 방지)
$script:VerProc     = $null
$script:ExportProc  = $null

function Start-InstalledCheck {
    try {
        $script:VerProc = Start-Hidden "winget" "--version" -Redirect
        $script:VerDeadline = [DateTime]::Now.AddSeconds(20)
        Set-WgCard 'busy' 'winget 확인 중…'
    } catch {
        $script:VerProc = $null
        $script:HasWinget = $false
        Set-WgCard 'error' 'winget 없음 · 설치 불가'
        Show-WgMissing
    }
}

function Poll-WingetCheck {
    $p = $script:VerProc
    if (-not $p) { return }
    if (-not $p.HasExited -and [DateTime]::Now -lt $script:VerDeadline) { return }
    $script:VerProc = $null
    if (-not $p.HasExited) {
        # 처음 실행 등으로 느린 경우: 없다고 단정하지 않고 설치는 막지 않는다
        try { $p.Kill() } catch { }
        Set-WgCard 'warn' 'winget 응답이 느림'
        return
    }
    if ($p.ExitCode -ne 0) { $script:HasWinget = $false; Set-WgCard 'error' 'winget 없음 · 설치 불가'; Show-WgMissing; return }

    $ver = $null
    try { $out = $p.StandardOutput.ReadToEnd(); $ver = ConvertTo-WgVersion $out } catch { }
    # 테스트용: 환경변수 PI_TEST_WG_VERSION 이 있으면 그 값을 이 PC 버전으로 간주(‘업데이트 있음’ 화면 확인용)
    if ($env:PI_TEST_WG_VERSION) { $ver = ConvertTo-WgVersion $env:PI_TEST_WG_VERSION }
    $script:HasWinget = $true
    $script:WgLocalVer = $ver
    if ($ver -and $ver -ge [version]'1.4') { $script:WingetExtra = ' --disable-interactivity' }
    Set-WgCard 'ok' $(if ($ver) { "사용 가능 · v$ver" } else { '사용 가능' })
    Start-WgLatestCheck

    # 보조 export (설치가 이미 시작됐으면 생략)
    if ($script:Phase -ne 'idle') { return }
    $script:ExportFile = Join-Path $env:TEMP ("pi_export_{0}.json" -f [Environment]::TickCount)
    try {
        $script:ExportProc = Start-Hidden "winget" "export -o `"$($script:ExportFile)`" --source winget --accept-source-agreements$($script:WingetExtra)"
        $script:ExportDeadline = [DateTime]::Now.AddSeconds(90)
    } catch { $script:ExportProc = $null }
}

function Stop-Export {
    if ($script:ExportProc) {
        try { if (-not $script:ExportProc.HasExited) { $script:ExportProc.Kill() } } catch { }
        $script:ExportProc = $null
        Remove-Item $script:ExportFile -Force -ErrorAction SilentlyContinue
    }
}

function Poll-Export {
    $p = $script:ExportProc
    if (-not $p) { return }
    if (-not $p.HasExited -and [DateTime]::Now -lt $script:ExportDeadline) { return }
    if (-not $p.HasExited) { Stop-Export; return }
    $script:ExportProc = $null

    $ids = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
    try {
        if (Test-Path $script:ExportFile) {
            $j = Get-Content $script:ExportFile -Raw -Encoding UTF8 | ConvertFrom-Json
            foreach ($src in $j.Sources) { foreach ($pk in $src.Packages) { [void]$ids.Add($pk.PackageIdentifier) } }
        }
    } catch { }
    Remove-Item $script:ExportFile -Force -ErrorAction SilentlyContinue

    # 1단계에서 '미설치'로 둔 것 중 winget 목록에 있으면 '설치됨'으로 보충
    foreach ($e in $script:Entries) {
        if ($e.Status -eq 'none' -and $e.App.Id -and $ids.Contains($e.App.Id)) {
            Set-Status $e 'installed' $null "winget: $($e.App.Id)"
        }
    }
}

# ───────────────────────────── winget 최신 버전 확인 / 업데이트 ─────────────────────────────
# 최신 버전 = GitHub microsoft/winget-cli 의 최신 '정식' 릴리스(releases/latest, 프리뷰 제외).
# 업데이트 = 그 릴리스의 Microsoft.DesktopAppInstaller_8wekyb3d8bbwe.msixbundle 을 받아 Add-AppxPackage.
#   구성 요소(VCLibs 등)가 모자라 실패하면 같은 릴리스의 DesktopAppInstaller_Dependencies.zip 에서 먼저 설치하고 다시 시도.
#   Store 를 거치지 않으므로 Store 가 없는 PC에서도 되고, winget 이 아예 없는 PC의 '설치'에도 같은 방법을 쓴다.
#   전부 숨은 powershell.exe 에서 실행(이 런처 안 PowerShell 에서는 Appx 명령이 빈 결과를 내는 문제가 있었음).
#   명령은 -EncodedCommand 로 넘겨 따옴표 깨짐을 원천 차단.
$script:WgLocalVer  = $null
$script:WgLatestVer = $null
$script:WgLatestProc = $null
$script:WgUpdProc   = $null
$script:WgUpdating  = $false
$WgReleaseApi = 'https://api.github.com/repos/microsoft/winget-cli/releases/latest'
$WgStoreUri   = 'ms-windows-store://pdp/?ProductId=9NBLGGH4NNS1'   # Microsoft Store '앱 설치 관리자'

# winget 업데이트/설치 스크립트 (숨은 powershell.exe 에서 실행)
#   - 릴리스 정보(GitHub API)를 못 읽으면(접속 차단·요청 한도 초과 등) Microsoft 공식 단축 주소 aka.ms/getwinget 으로 본체를 받는다.
#   - 다운로드는 Invoke-WebRequest -> 실패하면 Windows 내장 curl.exe 로 한 번 더.
#   - 본체 설치가 실패하면 구성 요소(Dependencies.zip)를 먼저 설치하고 다시 시도(릴리스 정보가 있을 때만 가능).
#   - 그래도 실패하면 Poll-WgUpdate 가 Microsoft Store '앱 설치 관리자' 페이지를 안내.
$WgUpdateTemplate = @'
$ErrorActionPreference='Stop'; $ProgressPreference='SilentlyContinue'
[Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12
function Get-File($u, $f) {
  try { Invoke-WebRequest -UseBasicParsing -UserAgent 'ProgramInstaller' -Uri $u -OutFile $f }
  catch { Write-Output ('download failed: ' + $_.Exception.Message + ' -> retry with curl.exe')
          & curl.exe -L --fail -sS --ssl-no-revoke -A 'ProgramInstaller' -o $f $u; if ($LASTEXITCODE -ne 0) { throw ('curl.exe download failed (exit ' + $LASTEXITCODE + ')') } }
  $len = (Get-Item $f).Length; Write-Output ('downloaded ' + $len + ' bytes')
  if ($len -lt 1000000) { throw ('downloaded file is too small: ' + $len + ' bytes') }
}
try {
  $r = $null
  try { $r = Invoke-RestMethod -UseBasicParsing -Headers @{ 'User-Agent'='ProgramInstaller' } -Uri '__API__'; Write-Output ('release ' + $r.tag_name) }
  catch { Write-Output ('release info failed: ' + $_.Exception.Message + ' -> using https://aka.ms/getwinget') }
  $a = if ($r) { $r.assets | Where-Object { $_.name -like '*.msixbundle' } | Select-Object -First 1 }
  $bu = if ($a) { $a.browser_download_url } else { 'https://aka.ms/getwinget' }
  $f = Join-Path $env:TEMP 'Microsoft.DesktopAppInstaller_8wekyb3d8bbwe.msixbundle'
  Get-File $bu $f
  try { Add-AppxPackage -Path $f -ForceApplicationShutdown; Write-Output 'installed' }
  catch {
    Write-Output ('first try failed: ' + $_.Exception.Message + ' -> installing dependencies')
    $d = if ($r) { $r.assets | Where-Object { $_.name -eq 'DesktopAppInstaller_Dependencies.zip' } | Select-Object -First 1 }
    if (-not $d) { throw }
    $z = Join-Path $env:TEMP $d.name; $x = Join-Path $env:TEMP 'pi_winget_deps'
    Get-File $d.browser_download_url $z
    Expand-Archive -Path $z -DestinationPath $x -Force
    $arch = if ([Environment]::Is64BitOperatingSystem) { 'x64' } else { 'x86' }
    Get-ChildItem -Path $x -Recurse -Include *.appx,*.msix | Where-Object { $_.FullName -match ('\\' + $arch + '\\') } | ForEach-Object {
      try { Add-AppxPackage -Path $_.FullName -ForceApplicationShutdown; Write-Output ('dependency ' + $_.Name) }
      catch { Write-Output ('dependency skipped ' + $_.Name + ': ' + $_.Exception.Message) } }
    Add-AppxPackage -Path $f -ForceApplicationShutdown; Write-Output 'installed after dependencies'
    Remove-Item $z, $x -Recurse -Force -ErrorAction SilentlyContinue
  }
  Remove-Item $f -Force -ErrorAction SilentlyContinue
  exit 0
} catch { Write-Output ('ERROR: ' + $_.Exception.Message); exit 1 }
'@

function ConvertTo-WgVersion($s) {
    if ([string]$s -match '(\d+)\.(\d+)(?:\.(\d+))?') {
        $b = if ($matches[3]) { $matches[3] } else { '0' }
        return [version]"$($matches[1]).$($matches[2]).$b"
    }
    return $null
}
function Start-HiddenPs($script, [switch]$Redirect) {
    $enc = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($script))
    # 이 런처 안에서 띄운 powershell 은 모듈 경로(PSModulePath)를 물려받아 일부 명령(Get-FileHash·Expand-Archive 등)을 못 찾는 경우가 있었다 -> 시스템 기본값으로 시작
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = 'powershell.exe'; $psi.Arguments = "-NoProfile -ExecutionPolicy Bypass -EncodedCommand $enc"
    $psi.UseShellExecute = $false; $psi.CreateNoWindow = $true; $psi.WindowStyle = 'Hidden'; if ($Redirect) { $psi.RedirectStandardOutput = $true }
    $psi.EnvironmentVariables['PSModulePath'] = [Environment]::GetEnvironmentVariable('PSModulePath', 'Machine')
    return [System.Diagnostics.Process]::Start($psi)
}
function Set-WgSub($text, $color = '#5B6270') {
    $WgSub.Text = $text
    $WgSub.Foreground = Brush $color
    $WgSub.Visibility = if ($text) { 'Visible' } else { 'Collapsed' }
}
function Set-WgButton($text) {
    if ($text) { $WgUpdateText.Text = $text; $WgUpdateBtn.Visibility = 'Visible' } else { $WgUpdateBtn.Visibility = 'Collapsed' }
}
function Show-WgMissing {
    Set-WgSub '프로그램을 설치하려면 winget이 필요합니다.' '#B42318'
    Set-WgButton 'winget 설치하기'
}

function Start-WgLatestCheck {
    Set-WgSub '최신 버전 확인 중…'
    $cmd = "[Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12; `$ProgressPreference='SilentlyContinue'; " +
           "try { `$r=Invoke-RestMethod -UseBasicParsing -Headers @{ 'User-Agent'='ProgramInstaller' } -Uri '$WgReleaseApi'; Write-Output `$r.tag_name } catch { exit 1 }"
    try { $script:WgLatestProc = Start-HiddenPs $cmd -Redirect; $script:WgLatestDeadline = [DateTime]::Now.AddSeconds(20) }
    catch { $script:WgLatestProc = $null; Set-WgSub '' }
}
function Poll-WgLatest {
    $p = $script:WgLatestProc
    if (-not $p) { return }
    if (-not $p.HasExited -and [DateTime]::Now -lt $script:WgLatestDeadline) { return }
    $script:WgLatestProc = $null
    if (-not $p.HasExited) { try { $p.Kill() } catch { }; Set-WgSub '최신 버전을 확인하지 못했습니다'; return }
    $tag = ''; try { $tag = $p.StandardOutput.ReadToEnd().Trim() } catch { }
    $latest = ConvertTo-WgVersion $tag
    if ($p.ExitCode -ne 0 -or -not $latest) { Set-WgSub '최신 버전을 확인하지 못했습니다 (인터넷 연결 확인)'; return }
    $script:WgLatestVer = $latest
    if ($script:WgLocalVer -and $script:WgLocalVer -ge $latest) {
        Set-WgSub '최신 버전입니다' '#1E6B3A'
        Set-WgButton $null
    } else {
        Set-WgSub "새 버전(v$latest)이 있습니다" '#B54708'
        Set-WgCard 'warn' $(if ($script:WgLocalVer) { "사용 가능 · v$($script:WgLocalVer)" } else { '사용 가능' })
        Set-WgButton "업데이트 (v$latest)"
    }
    Write-Log "winget: 이 PC v$($script:WgLocalVer) / 최신 정식 v$latest"
}

$WgUpdateBtn.Add_Click({
    if ($script:WgUpdating) { return }
    if ($script:Phase -ne 'idle') { Show-Msg "프로그램 설치가 끝난 뒤에 winget을 업데이트해 주세요." | Out-Null; return }
    $installing = ($script:HasWinget -eq $false)
    $what = if ($installing) { 'winget(앱 설치 관리자)을 설치' } else { "winget을 최신 버전(v$($script:WgLatestVer))으로 업데이트" }
    $r = Show-Msg "$what 합니다.`n`n- Microsoft 공식 배포본(GitHub microsoft/winget-cli)을 내려받습니다(약 200MB, 필요하면 구성 요소 약 90MB 추가).`n- 진행하는 동안 실행 중인 winget은 종료됩니다.`n`n진행할까요?" 'winget' 'YesNo' 'Question'
    if ($r -ne 'Yes') { return }
    $cmd = $WgUpdateTemplate.Replace('__API__', $(if ($env:PI_TEST_WG_NOAPI) { 'https://api.github.com/repos/invalid-test/none/releases/latest' } else { $WgReleaseApi }))
    try { $script:WgUpdProc = Start-HiddenPs $cmd -Redirect } catch { Show-Msg "업데이트를 시작하지 못했습니다: $($_.Exception.Message)" | Out-Null; return }
    $script:WgUpdating = $true
    $script:WgUpdDeadline = [DateTime]::Now.AddMinutes(20)
    $script:WgUpdStarted = [DateTime]::Now
    $InstallBtn.IsEnabled = $false          # 업데이트 중에는 설치를 막는다(winget 이 교체되는 중)
    $WgUpdateBtn.IsEnabled = $false
    Set-WgCard 'busy' $(if ($installing) { 'winget 설치 중…' } else { 'winget 업데이트 중…' })
    Set-WgSub '내려받는 중… (몇 분 걸릴 수 있습니다)'
    Write-Log "winget $(if ($installing) { '설치' } else { '업데이트' }) 시작 (GitHub 최신 정식 릴리스)"
})

function Poll-WgUpdate {
    $p = $script:WgUpdProc
    if (-not $p) { return }
    if (-not $p.HasExited) {
        if ([DateTime]::Now -lt $script:WgUpdDeadline) {
            $el = [DateTime]::Now - $script:WgUpdStarted
            Set-WgSub ("진행 중… {0}:{1:00}" -f [int][Math]::Floor($el.TotalMinutes), $el.Seconds)
            return
        }
        try { $p.Kill() } catch { }
    }
    $script:WgUpdProc = $null
    $script:WgUpdating = $false
    $WgUpdateBtn.IsEnabled = $true
    if (-not $script:Busy) { $InstallBtn.IsEnabled = $true }
    $out = ''; try { $out = $p.StandardOutput.ReadToEnd() } catch { }
    foreach ($l in ($out -split "`r?`n")) { if ($l.Trim()) { Write-Log "  └ $($l.Trim())" } }
    if ($p.HasExited -and $p.ExitCode -eq 0) {
        Write-Log "winget 업데이트 완료"
        Set-WgButton $null
        Start-InstalledCheck            # 버전을 다시 읽어 카드 갱신 (최신 여부도 다시 확인)
        return
    }
    Write-Log "winget 업데이트 실패 (종료코드 $(if ($p.HasExited) { $p.ExitCode } else { '시간 초과' }))"
    Set-WgCard $(if ($script:HasWinget) { 'warn' } else { 'error' }) $(if ($script:HasWinget) { "사용 가능 · v$($script:WgLocalVer)" } else { 'winget 없음 · 설치 불가' })
    Set-WgSub '자동 업데이트에 실패했습니다. 로그를 확인해 주세요.' '#B42318'
    $r = Show-Msg "winget 자동 업데이트에 실패했습니다.`n자세한 내용은 로그(install_log.txt)에 남겼습니다.`n`nMicrosoft Store의 '앱 설치 관리자' 페이지를 열까요?`n(Store에서 '업데이트'를 누르면 됩니다)" 'winget' 'YesNo' 'Warning'
    if ($r -eq 'Yes') { try { Start-Process $WgStoreUri } catch { Show-Msg "Microsoft Store를 열 수 없습니다." | Out-Null } }
}

# ───────────────────────────── 설치 엔진 ─────────────────────────────
$script:Phase = 'idle'   # idle → syncing → installing → idle
$script:installQueue = New-Object System.Collections.Generic.Queue[object]
$script:runningJobs = New-Object System.Collections.Generic.List[object]
$script:retryQueue = New-Object System.Collections.Generic.Queue[object]
# 순차 설치(한 번에 하나씩): 담은 순서대로 진행하고, 실패하면 그 자리에서 바로 재시도/대체 다운로드까지 마친 뒤 다음으로 넘어간다.
#   (동시 3개일 때는 화면에서 무엇이 어떻게 진행되는지 따라가기 어려웠고, MSI/의존성 설치끼리 겹쳐 1618·0x8A150102·0x8A150110 실패도 났음)
$script:MaxConcurrent = 1
$script:JobTimeoutMin = 20  # 한 프로그램 설치가 이 시간(분)을 넘으면 기다리기를 멈추고 '시간 초과'로 표시

function Set-Busy($busy) {
    $InstallBtn.IsEnabled = -not $busy
    $PathBox.IsEnabled = -not $busy
    $BrowseBtn.IsEnabled = -not $busy
    $AllCheck.IsEnabled = -not $busy
    $AddCartBtn.IsEnabled = -not $busy
    $CartClearBtn.IsEnabled = -not $busy
    $script:Busy = $busy
    foreach ($e in $script:Entries) { $e.Cb.IsEnabled = ((-not $busy) -and ($e.Status -ne 'installed')) }
    foreach ($e in $script:Cart) { if ($e.CartRm) { $e.CartRm.IsEnabled = -not $busy } }
    if ($busy) { $InstallText.Text = '순차 설치 중…' } else { Update-CartUi }
}

# 포터블 프로그램: EXE 옆에 받아둔 폴더를 복사하고 바탕화면/시작 메뉴 바로가기를 만든다
function Install-Portable($e) {
    $app = $e.App
    $src = Join-Path $ScriptDir $app.Portable
    if (-not (Find-PortableExe $src $app.Exe)) {
        Write-Log "건너뜀 (폴더 없음): $($app.Name) - $src"
        Set-Status $e 'skipped' '파일 없음' $app.Note
        $script:FailCount++
        return
    }
    try {
        Write-Log "설치 중(포터블 복사): $($app.Name)"
        $dst = Get-PortableTarget $app
        New-Item -ItemType Directory -Force -Path $dst | Out-Null
        Copy-Item -Path (Join-Path $src '*') -Destination $dst -Recurse -Force
        $exe = Find-PortableExe $dst $app.Exe
        $shell = New-Object -ComObject WScript.Shell
        foreach ($dir in @([Environment]::GetFolderPath('Desktop'), [Environment]::GetFolderPath('Programs'))) {
            $lnk = $shell.CreateShortcut((Join-Path $dir "$($app.Name).lnk"))
            $lnk.TargetPath = $exe
            $lnk.WorkingDirectory = Split-Path $exe
            $lnk.Save()
        }
        Write-Log "완료: $($app.Name) -> $dst"
        Set-Status $e 'done' $null $exe
        $script:OkCount++
    } catch {
        Write-Log "실패: $($app.Name) - $($_.Exception.Message)"
        Set-Status $e 'failed' $null $_.Exception.Message
        $script:FailCount++
    }
}

# ───────────── winget 실패 대응: 대체 다운로드 (도구가 직접 받아서 설치) ─────────────
# winget 이 설치하지 못하면(다운로드 오류는 바로, 그 밖의 오류는 winget 재시도까지 실패한 뒤) 이 도구가 직접 받아 설치한다.
#  - 'winget show' 로 winget 목록의 공식 설치 파일 주소·종류·SHA256 을 읽는다(표시 언어와 무관하게 줄 모양으로).
#  - 받는 방법 3가지를 차례로: Invoke-WebRequest -> Windows 내장 curl.exe -> BITS(Start-BitsTransfer). 전부 실패하면 10초 뒤 한 번 더.
#  - 받은 파일은 SHA256 이 목록과 같아야 실행. 다르면(제조사가 파일을 새로 올림) 디지털 서명이 '유효'할 때만 실행.
#  - 무인 설치 옵션: winget 공식 매니페스트 저장소(github.com/microsoft/winget-pkgs)의 installer.yaml 에 적힌 Silent 값을 쓰고,
#    없으면 종류별 기본값(msi/wix /qn, nullsoft /S, inno /VERYSILENT…, burn /quiet). 끝내 옵션을 모르는 exe 만 설치 창을 띄운다.
#  - 사용자에게 '직접 받아 설치하라'고 넘기지 않는다(2026-11-08 사용자 요청으로 공식 페이지 안내 제거).
# winget 의 다운로드 오류로 보는 종료코드: 0x8A150008(다운로드 실패), 0x80072EE0~0x80072FA7(인터넷 연결/TLS),
#   0x80D0xxxx(전송 최적화), 0x8019xxxx(HTTP 오류, 404 제외)
function Test-DownloadFailure($code) {
    $u = [int64]$code; if ($u -lt 0) { $u += 4294967296 }
    $h = { param($s) [Convert]::ToInt64($s, 16) }
    if ($u -eq (& $h '8A150008')) { return $true }
    if ($u -ge (& $h '80072EE0') -and $u -le (& $h '80072FA7')) { return $true }
    if ($u -ge (& $h '80D00000') -and $u -le (& $h '80D0FFFF')) { return $true }
    if ($u -ge (& $h '80190000') -and $u -le (& $h '8019FFFF') -and $u -ne (& $h '80190194')) { return $true }
    return $false
}

$FallbackTemplate = @'
$ErrorActionPreference='Stop'; $ProgressPreference='SilentlyContinue'
[Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12
function Get-Dl($u, $f) {
  for ($round = 1; $round -le 2; $round++) {
    try { Invoke-WebRequest -UseBasicParsing -UserAgent 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)' -Uri $u -OutFile $f; Write-Output 'downloaded (web)'; return }
    catch { Write-Output ('download (web) failed: ' + $_.Exception.Message) }
    & curl.exe -L --fail -sS --retry 2 --ssl-no-revoke -A 'Mozilla/5.0' -o $f $u 2>&1 | Out-Null
    if ($LASTEXITCODE -eq 0) { Write-Output 'downloaded (curl.exe)'; return }
    Write-Output ('download (curl.exe) failed: exit ' + $LASTEXITCODE)
    try { Import-Module BitsTransfer -ErrorAction Stop; Start-BitsTransfer -Source $u -Destination $f -ErrorAction Stop; Write-Output 'downloaded (BITS)'; return }
    catch { Write-Output ('download (BITS) failed: ' + $_.Exception.Message) }
    if ($round -eq 1) { Write-Output 'all download methods failed - trying again in 10s'; Start-Sleep -Seconds 10 }
  }
  throw 'download failed (web, curl.exe, BITS - 2 rounds)'
}
try {
  # winget 출력은 UTF-8 -> 읽을 때만 UTF-8 로 바꾸고 되돌린다 (이 스크립트의 출력은 런처가 기본 인코딩으로 읽음)
  $oe = [Console]::OutputEncoding; [Console]::OutputEncoding = [Text.Encoding]::UTF8
  try { $info = (& winget show --id '__ID__' -e --source winget --accept-source-agreements__EXTRA__ 2>&1 | Out-String) } finally { [Console]::OutputEncoding = $oe }
  # '설치 관리자' 부분: URL 바로 다음 줄이 SHA256 (표시 언어와 상관없이 모양으로 찾음)
  $m = [regex]::Match($info, '(?m)^[ \t]+[^:\r\n]+:[ \t]*(https?://\S+)[ \t]*\r?\n[ \t]+[^:\r\n]+:[ \t]*([0-9A-Fa-f]{64})')
  if (-not $m.Success) { throw 'installer url not found (winget show)' }
  $u = $m.Groups[1].Value; $sha = $m.Groups[2].Value.ToUpper()
  # 종류는 URL 위 몇 줄 중 알려진 종류 값 (사이에 '로캘' 줄이 끼는 경우가 있음)
  $type = 'exe'
  $above = @($info.Substring(0, $m.Index) -split '\r?\n' | Select-Object -Last 6)
  foreach ($ln in $above) { if ($ln -match ':[ \t]*(msix|msi|appx|exe|zip|inno|nullsoft|wix|burn|pwa|portable)[ \t]*$') { $type = $matches[1].ToLower() } }
  __TEST__
  Write-Output ('installer: ' + $type + ' ' + $u)
  if ($type -in @('zip','portable')) { throw ('installer type ' + $type + ' is not supported') }
  # 무인 설치 옵션: winget 공식 매니페스트(installer.yaml)의 Silent 값
  $silent = $null
  $ver = [regex]::Match($info, '(?m)^(?:버전|Version):\s*(\S+)')
  if ($ver.Success -and $type -notin @('msi','wix','msix','appx')) {
    try {
      $id = '__ID__'
      $mp = 'manifests/' + $id.Substring(0,1).ToLower() + '/' + ($id.Split('.') -join '/') + '/' + $ver.Groups[1].Value + '/' + $id + '.installer.yaml'
      $y = (Invoke-WebRequest -UseBasicParsing -UserAgent 'ProgramInstaller' -Uri ('https://raw.githubusercontent.com/microsoft/winget-pkgs/master/' + $mp)).Content
      $ix = $y.IndexOf($u)
      if ($ix -ge 0) {
        $bs = $y.LastIndexOf("`n- ", $ix); if ($bs -lt 0) { $bs = 0 }
        $be = $y.IndexOf("`n- ", $ix); if ($be -lt 0) { $be = $y.Length }
        $mm = [regex]::Match($y.Substring($bs, $be - $bs), '(?m)^\s+Silent:\s*(.+?)\s*$'); if ($mm.Success) { $silent = $mm.Groups[1].Value }
      }
      $ins = $y.IndexOf('Installers:')
      if (-not $silent -and $ins -gt 0) { $mm = [regex]::Match($y.Substring(0, $ins), '(?m)^\s+Silent:\s*(.+?)\s*$'); if ($mm.Success) { $silent = $mm.Groups[1].Value } }
      if ($silent) { $silent = $silent.Trim([char]39, [char]34); Write-Output ('silent switches (winget manifest): ' + $silent) }
    } catch { Write-Output ('manifest switches not available: ' + $_.Exception.Message) }
  }
  $ext = if ($type -in @('msi','wix')) { 'msi' } elseif ($type -in @('msix','appx')) { 'msix' } else { 'exe' }
  $f = Join-Path $env:TEMP ('ProgramInstaller_fb___SAFE__.' + $ext)
  Get-Dl $u $f
  $len = (Get-Item $f).Length; Write-Output ('downloaded ' + $len + ' bytes')
  if ($len -lt 100000) { throw ('downloaded file is too small: ' + $len + ' bytes') }
  # SHA256 (.NET 으로 직접 계산: 런처에서 띄운 powershell 에서는 Get-FileHash 를 못 찾는 경우가 있었음)
  $fs = [IO.File]::OpenRead($f); try { $got = -join ([Security.Cryptography.SHA256]::Create().ComputeHash($fs) | ForEach-Object { $_.ToString('X2') }) } finally { $fs.Close() }
  if ($got -eq $sha) { Write-Output 'sha256 ok' }
  elseif ($ext -eq 'msix') { Write-Output 'sha256 differs - package signature is checked by Windows when installing' }
  else {
    Import-Module Microsoft.PowerShell.Security -ErrorAction SilentlyContinue
    $sig = Get-AuthenticodeSignature -FilePath $f
    if ($sig.Status -ne 'Valid') { throw ('sha256 differs from winget list and digital signature is ' + $sig.Status + ' - not installed') }
    Write-Output ('sha256 differs from winget list (newer file) - digital signature valid: ' + $sig.SignerCertificate.Subject)
  }
  $code = 0
  if ($ext -eq 'msix') { Add-AppxPackage -Path $f -ForceApplicationShutdown }
  elseif ($ext -eq 'msi') {
    for ($i=0; $i -lt 120; $i++) { $busy=$false
      try { [Threading.Mutex]::OpenExisting('Global\_MSIExecute').Close(); $busy=$true } catch [Threading.WaitHandleCannotBeOpenedException] { } catch { $busy=$true }
      if (-not $busy) { break }; if ($i -eq 0) { Write-Output 'another MSI install is running - waiting' }; Start-Sleep -Seconds 5 }
    $code = (Start-Process msiexec -ArgumentList ('/i "' + $f + '" /qn /norestart') -Wait -PassThru).ExitCode
  } else {
    $a = if ($silent) { $silent } else { switch ($type) { 'nullsoft' { '/S' } 'inno' { '/VERYSILENT /SUPPRESSMSGBOXES /NORESTART /SP-' } 'burn' { '/quiet /norestart' } default { '' } } }
    # -Wait 는 자식 프로세스까지 기다리므로 쓰지 않고 설치 프로그램 자신만 기다린다
    if (-not $a) { Write-Output 'interactive installer - follow the setup window' }
    $p = if ($a) { Start-Process -FilePath $f -ArgumentList $a -PassThru } else { Start-Process -FilePath $f -PassThru }
    $null = $p.Handle; $p.WaitForExit(); $code = $p.ExitCode
  }
  Write-Output ('installer exit code ' + $code)
  Remove-Item $f -ErrorAction SilentlyContinue
  exit $code
} catch { Write-Output ('ERROR: ' + $_.Exception.Message); exit 1 }
'@
function Get-FallbackScript($app) {
    $test = if ($env:PI_TEST_FB_BADURL) { "`$u = 'https://invalid.example.invalid/setup.exe'; Write-Output 'TEST: bad url'" } else { '' }
    return $FallbackTemplate.Replace('__ID__', $app.Id.Replace("'", "''")).Replace('__EXTRA__', $script:WingetExtra).
        Replace('__SAFE__', ($app.Id -replace '[^\w\.\-]', '_')).Replace('__TEST__', $test)
}

function Get-StartStage($e) {
    # 담은 항목 화면에 보여 줄 '지금 하는 일' (어떤 방법으로 몇 번째 시도 중인지)
    $app = $e.App
    $again = if ($e.Retried) { '다시 시도: ' } else { '' }
    $s = if ($app.Portable) { '파일을 복사하는 중…' }
         elseif ($e.UseFallback) { 'winget 다운로드 실패 → 대체 다운로드 중: winget 목록의 공식 주소에서 직접 받아 설치합니다…' }
         elseif (-not $app.Id) { '설치 파일을 실행하는 중…' }
         elseif ($app.DirectUrl -and -not $e.DirectFailed) { "${again}공식 사이트에서 설치 파일을 받아 설치하는 중…" }
         elseif ($e.DirectFailed) { '직접 다운로드 실패 → winget으로 다시 받아 설치하는 중…' }
         elseif ($app.Source -eq 'msstore') { "${again}Microsoft Store에서 받아 설치하는 중…" }
         elseif ($e.IgnoreHash) { '다시 시도: 파일 확인값이 달라 해시 검사 없이 winget으로 설치하는 중…' }
         elseif ($e.SkipDeps) { '다시 시도: 구성 요소를 건너뛰고 winget으로 설치하는 중…' }
         else { "${again}winget으로 받아 설치하는 중…" }
    if ($app.Interactive) { $s += " · 설치 창이 뜨면 '설치'를 눌러 주세요" }
    return $s
}

function Start-AppInstall($e) {
    $app = $e.App
    Set-Stage $e (Get-StartStage $e) '#1E47B3'
    if ($e.CartRow) { try { $e.CartRow.BringIntoView() } catch { } }
    if ($app.Portable) { Install-Portable $e; return }
    if ($e.UseFallback) {
        # winget 다운로드 실패 -> winget 목록에 적힌 공식 설치 파일 주소에서 직접 받아 설치 (Get-FallbackScript 참고)
        $e.UseFallback = $false
        Write-Log "설치 중(대체 다운로드: winget 목록의 공식 주소에서 직접 받기): $($app.Name) [$($app.Id)]"
        try { $proc = Start-HiddenPs (Get-FallbackScript $app) -Redirect }
        catch { Write-Log "실행 실패: $($app.Name) - $($_.Exception.Message)"; Set-Status $e 'failed' $null $_.Exception.Message; $script:FailCount++; return }
        Set-Status $e 'installing'
        $script:runningJobs.Add([PSCustomObject]@{ Entry = $e; App = $app; Proc = $proc; Stage = 'installing'; Deadline = $null; Started = [DateTime]::Now; Direct = $true; Fallback = $true; NextCheck = [DateTime]::Now })
        return
    }
    try {
        if ($app.Id) {
            # winget으로 설치 (Store 앱은 msstore 소스, 설치 위치 지정 불가)
            $src = if ($app.Source) { $app.Source } else { 'winget' }
            # 직접 설치 대상은 재시도도 직접 설치로 한다 (winget 쪽은 해시 불일치/404로 어차피 실패)
            if ($app.DirectUrl -and -not $e.DirectFailed) {
                # winget 목록의 해시가 계속 낡는 프로그램(Chrome/웨일/허니뷰/카카오톡): 제조사 공식 주소의 설치 파일을 직접 받아 조용히 설치.
                # 실패하면 재시도도 같은 직접 설치로 한 번 더 시도한다.
                Write-Log "설치 중(공식 설치 파일 직접 다운로드): $($app.Name)"
                $isMsi = $app.DirectUrl -match '\.msi($|\?)'
                $ext = if ($isMsi) { 'msi' } else { 'exe' }
                # MSI는 PC 전체에서 한 번에 하나만 설치된다(다른 MSI 설치 중이면 1618).
                # -> 다른 MSI 설치(Global\_MSIExecute)가 끝날 때까지 최대 10분 기다렸다가 실행하고, 그래도 1618이면 30초 뒤 다시(최대 4번).
                $msiWait = "for (`$i=0; `$i -lt 120; `$i++) { `$busy=`$false; " +
                           "try { [Threading.Mutex]::OpenExisting('Global\_MSIExecute').Close(); `$busy=`$true } catch [Threading.WaitHandleCannotBeOpenedException] { } catch { `$busy=`$true }; " +
                           "if (-not `$busy) { break }; if (`$i -eq 0) { Write-Output 'another MSI install is running - waiting' }; Start-Sleep -Seconds 5 }; "
                $run = if ($isMsi) { "`$tries=0; do { if (`$tries -gt 0) { Write-Output 'exit 1618 - retry in 30s'; Start-Sleep -Seconds 30 }; $msiWait" +
                                     "`$p=Start-Process msiexec -ArgumentList '/i',`$f,'/qn','/norestart' -Wait -PassThru; `$tries++ } while (`$p.ExitCode -eq 1618 -and `$tries -lt 4)" }
                       # 주의: Windows PowerShell 의 Start-Process -Wait 는 설치 프로그램이 띄운 '자식 프로세스'(설치 끝에 실행된 앱 등)까지
                       #       전부 끝나야 돌아온다 -> 어사이드처럼 설치 후 앱을 바로 실행하면 20분 시간 초과가 났다.
                       #       설치 프로그램 자신만 기다린다(.Handle 을 먼저 읽어야 종료코드를 받을 수 있음).
                       elseif ($app.DirectArgs) { "`$p=Start-Process -FilePath `$f -ArgumentList '$($app.DirectArgs)' -PassThru; `$null=`$p.Handle; `$p.WaitForExit()" }
                       else { "`$p=Start-Process -FilePath `$f -PassThru; `$null=`$p.Handle; `$p.WaitForExit()" }
                if ($app.Interactive) { Write-Log "안내: $($app.Name) 설치 창이 뜹니다. 창에서 '설치'를 눌러 주세요." }
                # 주의: 오류를 무시하고 끝까지 가면 exit 값이 비어 '종료코드 0(성공)'으로 보이므로
                #       ErrorAction=Stop + try/catch 로 실패를 분명히 잡고, 진행 내용을 출력해 로그에 남긴다.
                $cmd = "`$ErrorActionPreference='Stop'; `$ProgressPreference='SilentlyContinue'; [Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12; " +
                       "try { " +
                       "`$f=Join-Path `$env:TEMP 'ProgramInstaller_$($app.Id).$ext'; " +
                       "`$u='$($app.DirectUrl)'; " +
                       # DirectPage: 설치 파일 주소에 버전이 박혀 있는 프로그램(어사이드·지니)은 공식 다운로드 페이지에서 최신 주소를 읽는다.
                       #             못 읽으면 DirectUrl(마지막으로 확인한 주소)을 그대로 쓴다. (패턴에 따옴표 쓰지 말 것)
                       $(if ($app.DirectPage) {
                       "try { `$pg=(Invoke-WebRequest -UseBasicParsing -UserAgent 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)' -Uri '$($app.DirectPage)').Content; " +
                       "`$m=[regex]::Match(`$pg, '$($app.DirectPattern)'); if (`$m.Success) { `$u=`$m.Value; Write-Output ('latest url: ' + `$u) } else { Write-Output 'latest url not found on page - using saved url' } } " +
                       "catch { Write-Output ('download page failed: ' + `$_.Exception.Message + ' - using saved url') }; " } else { '' }) +
                       # 1차: Invoke-WebRequest / 실패하면(인증서·TLS 문제 등) Windows 기본 내장 curl.exe 로 한 번 더
                       "try { Invoke-WebRequest -UseBasicParsing -UserAgent 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)' -Uri `$u -OutFile `$f } " +
                       "catch { Write-Output ('download failed: ' + `$_.Exception.Message + ' -> retry with curl.exe'); " +
                       "& curl.exe -L --fail -sS --ssl-no-revoke -A 'Mozilla/5.0' -o `$f `$u; if (`$LASTEXITCODE -ne 0) { throw ('curl.exe download failed (exit ' + `$LASTEXITCODE + ')') } }; " +
                       "`$len=(Get-Item `$f).Length; Write-Output ('downloaded ' + `$len + ' bytes'); " +
                       "if (`$len -lt 1000000) { throw ('downloaded file is too small: ' + `$len + ' bytes') }; " +
                       "$run; Write-Output ('installer exit code ' + `$p.ExitCode); " +
                       "Remove-Item `$f -ErrorAction SilentlyContinue; exit `$p.ExitCode " +
                       "} catch { Write-Output ('ERROR: ' + `$_.Exception.Message); exit 1 }"
                $proc = Start-Hidden "powershell.exe" "-NoProfile -ExecutionPolicy Bypass -Command `"$cmd`"" -Redirect
                Set-Status $e 'installing'
                $script:runningJobs.Add([PSCustomObject]@{ Entry = $e; App = $app; Proc = $proc; Stage = 'installing'; Deadline = $null; Started = [DateTime]::Now; Direct = $true; NextCheck = [DateTime]::Now })
                return
            }
            Write-Log "설치 중($src): $($app.Name) [$($app.Id)]"
            $baseArgs = "install --id $($app.Id) -e --source $src --accept-package-agreements --accept-source-agreements"
            $basePath = $PathBox.Text.Trim()
            if ($basePath -ne "" -and $src -eq 'winget') {
                $safeName = ($app.Name -replace '[^\w\-]', '_')
                $baseArgs += " --location `"$(Join-Path $basePath $safeName)`""
            } elseif ($app.DefaultLocation -and $src -eq 'winget') {
                # 설치 위치가 꼭 필요한 패키지(Battle.net: 0x8A15005F) -> 기본 위치를 지정
                $baseArgs += " --location `"$([Environment]::ExpandEnvironmentVariables($app.DefaultLocation))`""
            }
            $hashArg = ''
            if ($e.SkipDeps) { $hashArg += ' --skip-dependencies'; Write-Log "의존성 건너뛰고 재시도: $($app.Name) (--skip-dependencies)" }
            if ($e.IgnoreHash -or $app.IgnoreHash) {
                # 설치 파일 해시 불일치(0x8A150011): 항상 최신 파일을 받는 주소(Chrome 등)는 새 버전이 나오면
                # winget 목록의 해시가 낡아 실패한다. 이 경우에만 해시 검사를 건너뛰고 다시 시도한다.
                # (설치 파일은 목록에 적힌 공식 주소에서 HTTPS로 받아온다)
                try {
                    $sp = Start-Hidden "winget" "settings --enable InstallerHashOverride"
                    if ($sp) { [void]$sp.WaitForExit(20000) }
                } catch { }
                $hashArg = ' --ignore-security-hash'
                Write-Log "해시 불일치 재시도: $($app.Name) (--ignore-security-hash)"
            }
            $mode = '--silent --force'
            if ($app.Interactive) {
                # 조용히 설치하는 옵션이 없는 설치 프로그램 -> 설치 창이 뜨면 안내에 따라 진행
                $mode = '--interactive'
                Write-Log "안내: $($app.Name)은(는) 설치 창이 뜰 수 있습니다. 창이 보이면 '설치'를 눌러 주세요."
            }
            if ($env:PI_TEST_WG_DLFAIL) {
                # 테스트용: winget 다운로드 실패(0x8A150008)를 흉내 내 대체 다운로드 흐름을 확인
                Write-Log "TEST: winget 다운로드 실패 흉내 (0x8A150008)"
                $proc = Start-Hidden "powershell.exe" "-NoProfile -Command exit -1978335224"
            } else {
                $proc = Start-Hidden "winget" "$baseArgs $mode$hashArg$($script:WingetExtra)"
            }
        } else {
            # winget에서 계속 실패하는 프로그램 -> 같은 폴더의 로컬 설치파일로 설치
            $exePath = Join-Path $ScriptDir $app.File
            if (-not (Test-Path $exePath)) {
                Write-Log "건너뜀 (파일 없음): $($app.Name) - $($app.File)"
                Set-Status $e 'skipped' '파일 없음'
                $script:FailCount++
                return
            }
            Write-Log "설치 중(로컬 파일): $($app.Name)"
            $argList = $app.Args
            $basePath = $PathBox.Text.Trim()
            if ($basePath -ne "" -and $app.PathTemplate) {
                $safeName = ($app.Name -replace '[^\w\-]', '_')
                $argList = ($argList + " " + ($app.PathTemplate -f (Join-Path $basePath $safeName))).Trim()
            }
            $proc = Start-Hidden $exePath $argList
        }
    } catch {
        Write-Log "실행 실패: $($app.Name) - $($_.Exception.Message)"
        Set-Status $e 'failed' $null $_.Exception.Message
        $script:FailCount++
        return
    }
    Set-Status $e 'installing'
    $script:runningJobs.Add([PSCustomObject]@{ Entry = $e; App = $app; Proc = $proc; Stage = 'installing'; Deadline = $null; Started = [DateTime]::Now })
}

# winget/설치 프로그램 종료코드 해석 -> (결과, 표시 문구)
#   0x8A150061 이미 설치됨 / 0x8A15002B 적용할 업데이트 없음(=최신) / 0x8A150109 재부팅해야 완료
#   0x8A150014 패키지를 찾을 수 없음 / 3010·1641 재부팅 필요(MSI)
function Get-InstallResult($code) {
    switch ($code) {
        0           { return @('done',   $null) }
        3010        { return @('done',   '재부팅 필요') }
        1641        { return @('done',   '재부팅 필요') }
        -1978334967 { return @('done',   '재부팅 필요') }
        -1978335135 { return @('done',   '이미 설치됨') }
        -1978335189 { return @('done',   '최신 버전') }
        -1978335212 { return @('failed', '패키지 없음') }
        -1978335215 { return @('failed', '설치 파일 해시 불일치') }
        -2145844844 { return @('failed', '다운로드 주소 없음(404)') }
        -1978335137 { return @('failed', '설치 위치 필요') }
        1618        { return @('failed', '다른 설치와 겹침') }
        -1978334974 { return @('failed', '다른 설치와 겹침') }
        -1978334960 { return @('failed', '구성 요소 설치 실패') }
        -2147012851 { return @('failed', '이 PC 인증서 문제') }
        default     { return @('failed', $null) }
    }
}

# Windows Update에서 Microsoft 공식 신뢰 루트 인증서 목록(SST)을 받아 '로컬 컴퓨터\신뢰할 수 있는 루트'에 추가
# (자동 루트 업데이트가 꺼진 PC에서 HTTPS 다운로드가 인증서 오류로 실패할 때 사용, 사용자 동의 후에만 실행)
function Update-RootCerts {
    $sst = Join-Path $env:TEMP 'ProgramInstaller_roots.sst'
    $window.Cursor = [Windows.Input.Cursors]::Wait
    try {
        Write-Log "루트 인증서 갱신: Windows Update에서 목록 받는 중..."
        Remove-Item $sst -ErrorAction SilentlyContinue
        $p = Start-Process -FilePath certutil.exe -ArgumentList '-f', '-generateSSTFromWU', "`"$sst`"" -Wait -PassThru -WindowStyle Hidden
        if ($p.ExitCode -ne 0 -or -not (Test-Path $sst)) { throw "certutil 실패 (종료코드 $($p.ExitCode))" }
        $col = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2Collection
        $col.Import($sst)
        $store = New-Object System.Security.Cryptography.X509Certificates.X509Store('Root', 'LocalMachine')
        $store.Open('ReadWrite')
        $before = $store.Certificates.Count
        $store.AddRange($col)
        $after = $store.Certificates.Count
        $store.Close()
        Write-Log "루트 인증서 갱신 완료: 목록 $($col.Count)개, 새로 추가 $($after - $before)개"
        $window.Cursor = $null
        Show-Msg "루트 인증서 갱신이 완료되었습니다. (새로 추가 $($after - $before)개)`n`n실패한 프로그램을 다시 선택해 설치해 주세요." "인증서 갱신" | Out-Null
    } catch {
        Write-Log "루트 인증서 갱신 실패: $($_.Exception.Message)"
        $window.Cursor = $null
        Show-Msg "루트 인증서 갱신에 실패했습니다.`n$($_.Exception.Message)" "인증서 갱신" 'OK' 'Warning' | Out-Null
    } finally {
        Remove-Item $sst -ErrorAction SilentlyContinue
    }
}

function Complete-Job($job, $code) {
    # 인증서 신뢰 실패(winget 0x80072F0D / curl 60 / .NET 트러스트 관계) -> 끝난 뒤 루트 인증서 갱신을 제안
    if ($code -eq -2147012851 -or ([string]$job.Output -match 'exit 60|트러스트 관계|trust relationship')) { $script:CertIssue = $true }
    $e = $job.Entry
    $hex = '0x{0:X8}' -f [int]$code
    $r = Get-InstallResult $code
    if ($r[0] -eq 'done') {
        Set-Status $e 'done' $r[1] "종료코드 $code ($hex)"
        Set-Stage $e ("설치 완료" + $(if ($r[1]) { " · $($r[1])" } else { '' })) '#1E6B3A'
        $script:OkCount++
        $e.Cb.IsChecked = $false     # 끝난 건 선택 해제 -> 다시 눌러도 중복 설치 안 함
        return
    }
    # winget 이 설치 파일을 못 받음(인터넷·TLS·전송 최적화 오류 등) -> winget 으로 다시 하지 않고 대체 다운로드로 재시도
    #   (msstore 앱은 설치 파일 주소가 없어 해당 없음 -> 끝나면 Store 페이지 안내)
    #   그 밖의 winget 실패도 winget 재시도까지 실패하면 대체 다운로드로 한 번 더 (사용자에게 '직접 받으라'고 넘기지 않는다)
    $canFb = (-not $job.Direct) -and (-not $e.FallbackTried) -and $e.App.Id -and $e.App.Source -ne 'msstore' -and $code -ne -1978335212
    $dlFail = Test-DownloadFailure $code
    if ($canFb -and ($dlFail -or $e.Retried)) {
        $e.FallbackTried = $true; $e.UseFallback = $true; $e.Retried = $true
        $why = if ($dlFail) { "winget 다운로드 실패 ($hex)" } else { "winget 재시도도 실패 ($hex" + $(if ($r[1]) { " · $($r[1])" } else { '' }) + ")" }
        Write-Log "$why : $($e.App.Name) -> 대체 다운로드(도구가 직접 받아 설치)로 재시도"
        Set-Status $e 'queued' '대체 다운로드' "${why}: 종료코드 $code"
        Set-Stage $e "$why → 도구가 공식 주소에서 직접 받아 설치하는 '대체 다운로드'로 바로 넘어갑니다" '#B54708'
        $script:retryQueue.Enqueue($e)
        return
    }
    # 실패는 한 번만, 나머지가 다 끝난 뒤 '하나씩' 다시 시도한다.
    # (여러 MSI 설치가 동시에 돌면 '다른 설치가 진행 중'으로 실패하는 경우가 흔함)
    if (-not $e.Retried -and $code -ne -1978335212) {
        $e.Retried = $true
        if ($code -eq -1978335215) { $e.IgnoreHash = $true }
        # 0x8A150110 의존성(VC++ 런타임 등) 설치 실패 -> 재시도 때는 의존성 설치를 건너뛰고 본 프로그램만 설치
        if ($code -eq -1978334960) { $e.SkipDeps = $true }
        # 직접 다운로드/설치가 실패(종료코드 1 = 다운로드 오류 등)하면 재시도는 winget 으로
        #   (DirectOnly = winget 에 없는 프로그램은 재시도도 직접 설치로)
        if ($job.Direct -and $code -eq 1 -and -not $e.App.DirectOnly) { $e.DirectFailed = $true }
        Write-Log "재시도 예약: $($e.App.Name) (종료코드 $code / $hex)"
        Set-Status $e 'queued' '재시도' "1차 실패: 종료코드 $code ($hex)"
        Set-Stage $e ("1차 실패 ($hex" + $(if ($r[1]) { " · $($r[1])" } else { '' }) + ") → 바로 다시 시도합니다") '#B54708'
        $script:retryQueue.Enqueue($e)
        return
    }
    Set-Status $e 'failed' $r[1] "종료코드 $code ($hex) · 로그 참고"
    Set-Stage $e ("설치 실패 ($hex" + $(if ($r[1]) { " · $($r[1])" } else { '' }) + ") · winget·재시도·대체 다운로드를 모두 시도했지만 설치하지 못했습니다 (로그 참고)") '#B42318'
    $script:FailCount++
}

function Fill-Slots {
    # 한 틱(200ms)에 하나씩만 채워서 winget 여러 개가 정확히 동시에 시작되며 생기는
    # 소스 잠금 충돌 가능성을 줄인다 (그래도 MaxConcurrent개까지는 금방 다 채워짐).
    # 순차 설치: 재시도(대체 다운로드 포함)가 있으면 그것부터 -> 한 프로그램을 끝까지 마치고 다음 프로그램으로
    if ($script:runningJobs.Count -ge $script:MaxConcurrent) { return }
    if ($script:retryQueue.Count -gt 0) { Start-AppInstall ($script:retryQueue.Dequeue()) }
    elseif ($script:installQueue.Count -gt 0) { Start-AppInstall ($script:installQueue.Dequeue()) }
}

function Step-Install {
    if ($script:Phase -eq 'syncing') {
        $p = $script:SyncProc
        if ($p -and -not $p.HasExited -and [DateTime]::Now -lt $script:SyncDeadline) { return }
        if (-not $p) { Write-Log "소스 동기화 건너뜀 (winget 실행 실패)" }
        elseif ($p.HasExited) { Write-Log "소스 동기화 완료" }
        else { Write-Log "소스 동기화가 오래 걸려 건너뛰고 진행합니다" }
        $script:Phase = 'installing'
    }
    if ($script:Phase -ne 'installing') { return }

    $stillRunning = New-Object System.Collections.Generic.List[object]
    foreach ($job in $script:runningJobs) {
        if ($job.Stage -eq 'installing') {
            if (-not $job.Proc.HasExited) {
                if ([DateTime]::Now -gt $job.Started.AddMinutes($script:JobTimeoutMin)) {
                    # 숨은 창에서 입력을 기다리는 설치 프로그램 등 -> 전체가 영원히 안 끝나는 것을 막는다 (프로세스는 건드리지 않음)
                    Write-Log "시간 초과: $($job.App.Name) ($($script:JobTimeoutMin)분 넘게 끝나지 않음)"
                    Set-Status $job.Entry 'warn' '시간 초과' "$($script:JobTimeoutMin)분이 지나도 설치가 끝나지 않았습니다. 설치 창이 숨어 있을 수 있습니다."
                    Set-Stage $job.Entry "$($script:JobTimeoutMin)분이 지나도 끝나지 않아 다음으로 넘어갑니다 · 숨은 설치 창이 있는지 확인해 주세요" '#B54708'
                    $script:FailCount++
                    continue
                }
                # 진행 중임을 알 수 있게 경과 시간을 표시
                $el = [DateTime]::Now - $job.Started
                Set-PillText $job.Entry ('설치 중… {0}:{1:00}' -f [int][Math]::Floor($el.TotalMinutes), $el.Seconds)
                $stillRunning.Add($job); continue
            }
            $code = $job.Proc.ExitCode
            Write-Log "완료: $($job.App.Name) (종료코드 $code)"
            if ($job.Direct) {
                $job | Add-Member -NotePropertyName Output -NotePropertyValue '' -Force
                try {
                    $job.Output = $job.Proc.StandardOutput.ReadToEnd()
                    foreach ($ln in ($job.Output -split "`r?`n")) {
                        if ($ln.Trim()) { Write-Log "  └ $($ln.Trim())" }
                        if ($ln -match '^homepage: (https?://\S+)') { $job.Entry.Homepage = $matches[1] }
                        if ($ln -match '^interactive installer') { $job | Add-Member -NotePropertyName LongVerify -NotePropertyValue $true -Force }
                    }
                } catch { }
            }
            # 일부 설치 프로그램(예: 크로미움 계열)은 실행 파일이 백그라운드에
            # 실제 설치를 넘기고 자기 자신은 먼저 종료해버림 -> 종료코드만 믿지 말고
            # 설치 결과물(VerifyPath)이 실제로 생길 때까지 별도로 기다려서 확인한다.
            # 직접 받아 설치한 프로그램: 설치 프로그램이 곧바로 종료하고 실제 설치는 뒤에서 이어지는 경우가 있어
            # (웨일 등) 종료코드 0만으로 '완료'라 하지 않고, 설치 목록(레지스트리)에 나타날 때까지 확인한다.
            if ($job.Direct -and $job.App.Match -and ($code -eq 0 -or $code -eq 3010 -or $code -eq 1641)) {
                $job.Stage = 'verifying'
                $waitSec = if ($job.App.Interactive -or $job.LongVerify) { 300 } else { 45 }
                $job.Deadline = [DateTime]::Now.AddSeconds($waitSec)
                $job.NextCheck = [DateTime]::Now
                Write-Log "설치 확인 대기 중: $($job.App.Name) (최대 ${waitSec}초)"
                Set-Status $job.Entry 'verifying'
                Set-Stage $job.Entry '설치 프로그램이 끝났습니다 · 실제로 설치됐는지 확인하는 중…' '#1E47B3'
                $stillRunning.Add($job)
                continue
            }
            if ($job.App.VerifyPath) {
                $timeoutSec = if ($job.App.VerifyTimeoutSec) { $job.App.VerifyTimeoutSec } else { 60 }
                $job.Stage = 'verifying'
                $job.Deadline = [DateTime]::Now.AddSeconds($timeoutSec)
                Write-Log "설치 확인 대기 중: $($job.App.Name) (최대 ${timeoutSec}초)"
                Set-Status $job.Entry 'verifying'
                Set-Stage $job.Entry '설치 프로그램이 끝났습니다 · 실제로 설치됐는지 확인하는 중…' '#1E47B3'
                $stillRunning.Add($job)
            } else {
                Complete-Job $job $code
            }
            continue
        }
        if ($job.Stage -eq 'verifying' -and $job.Direct) {
            $found = $false
            if ([DateTime]::Now -ge $job.NextCheck) {
                $job.NextCheck = [DateTime]::Now.AddSeconds(3)
                $found = Test-AppRegistered $job.App
            }
            if ($found) {
                Write-Log "설치 확인됨: $($job.App.Name)"
                Set-Status $job.Entry 'done'; Set-Stage $job.Entry $(if ($job.Fallback) { '대체 다운로드로 설치 완료 (설치 확인됨)' } else { '설치 완료 (설치 확인됨)' }) '#1E6B3A'; $script:OkCount++; $job.Entry.Cb.IsChecked = $false
            } elseif ([DateTime]::Now -gt $job.Deadline) {
                Write-Log "경고: $($job.App.Name) 설치 확인 실패 (설치 프로그램은 정상 종료했지만 설치 목록에 나타나지 않음)"
                Set-Status $job.Entry 'warn' '설치 확인 실패' '설치 프로그램이 오류 없이 끝났지만 설치된 것을 찾지 못했습니다. 다시 시도하거나 직접 설치해 주세요.'
                Set-Stage $job.Entry '설치 프로그램은 끝났지만 설치된 것을 찾지 못했습니다 · 다시 시도하거나 직접 설치해 주세요' '#B54708'
                $script:FailCount++
            } else {
                $stillRunning.Add($job)
            }
            continue
        }
        if ($job.Stage -eq 'verifying') {
            $vpath =[Environment]::ExpandEnvironmentVariables($job.App.VerifyPath)
            if (Test-Path $vpath) {
                Write-Log "설치 확인됨: $($job.App.Name)"
                Set-Status $job.Entry 'done'; Set-Stage $job.Entry $(if ($job.Fallback) { '대체 다운로드로 설치 완료 (설치 확인됨)' } else { '설치 완료 (설치 확인됨)' }) '#1E6B3A'; $script:OkCount++; $job.Entry.Cb.IsChecked = $false
            } elseif ([DateTime]::Now -gt $job.Deadline) {
                Write-Log "경고: $($job.App.Name) 설치 확인 실패 (시간 초과 - 실제로 설치되지 않았을 수 있음)"
                Set-Status $job.Entry 'warn' $null '시간 안에 설치 결과를 찾지 못했습니다'; $script:FailCount++
            } else {
                $stillRunning.Add($job)
            }
        }
    }
    $script:runningJobs = $stillRunning
    Fill-Slots

    Update-CartProgress

    if ($script:runningJobs.Count -eq 0 -and $script:installQueue.Count -eq 0 -and $script:retryQueue.Count -eq 0) {
        $script:Phase = 'idle'
        Write-Log "=== 모든 설치가 끝났습니다. (성공 $($script:OkCount), 실패/확인필요 $($script:FailCount)) ==="
        # 안전장치: 끝났는데도 '설치 중/확인 중/대기' 로 남은 줄이 있으면 정리
        foreach ($x in $script:Entries) {
            if ($x.Status -in @('installing', 'verifying', 'queued')) { Set-Status $x 'warn' '확인 필요' '설치 상태를 확인하지 못했습니다. 로그를 참고해 주세요.' }
        }
        Set-Busy $false
        Update-Selection
        $CartHead.Text = "순차 설치 끝 · 성공 $($script:OkCount)개" + $(if ($script:FailCount -gt 0) { " · 실패/확인 필요 $($script:FailCount)개" } else { '' })
        $CartProg.Value = $CartProg.Maximum
        $msg = "담은 프로그램 설치가 끝났습니다.`n`n성공 $($script:OkCount)개"
        if ($script:FailCount -gt 0) { $msg += " · 실패/확인 필요 $($script:FailCount)개 (로그 참고)" }
        # 타이머 처리 도중에 모달 창을 띄우면 화면 갱신이 멈춘 것처럼 보일 수 있어, 화면을 먼저 그린 뒤 띄운다
        $script:DoneMsg = $msg
        [void]$window.Dispatcher.BeginInvoke([Action]{
            Show-Msg $script:DoneMsg "완료" | Out-Null
            if ($script:CertIssue) {
                $script:CertIssue = $false
                $ans = Show-Msg ("일부 프로그램이 '인증서를 신뢰할 수 없음' 오류로 다운로드되지 않았습니다.`n" +
                                 "이 PC의 루트 인증서 목록이 오래되었거나 자동 업데이트가 꺼져 있을 때 생깁니다.`n`n" +
                                 "Windows Update에서 Microsoft 공식 루트 인증서 목록을 받아 갱신할까요?`n(갱신 후 실패한 항목을 다시 설치해 주세요)") "인증서 갱신" 'YesNo' 'Question'
                if ([string]$ans -eq 'Yes') { Update-RootCerts }
            }
        }, [Windows.Threading.DispatcherPriority]::ApplicationIdle)
    }
}

# 담은 항목 화면 위쪽: 순차 설치 진행 (몇 개 끝났는지 / 지금 무엇을 어떻게 설치하는지)
function Update-CartProgress {
    $doneN = $script:OkCount + $script:FailCount
    $SelText.Text = "설치 중 $doneN/$($script:TotalCount)"
    $cur = $null; foreach ($j in $script:runningJobs) { $cur = $j.Entry }
    $head = "순차 설치 중 · $doneN / $($script:TotalCount) 완료"
    if ($cur) { $head += " · 지금: $($cur.App.Name)" }
    $CartHead.Text = $head
    $CartProg.Maximum = [Math]::Max(1, $script:TotalCount)
    $CartProg.Value = $doneN
}

$InstallBtn.Add_Click({
    # 담은 항목 중 아직 끝나지 않은 것을 담은 순서대로 (이미 '완료/설치됨'은 건너뜀)
    $selected = @($script:Cart | Where-Object { $_.Status -notin @('done', 'installed') })
    if ($selected.Count -eq 0) {
        Show-Msg "설치할 항목이 없습니다.`n프로그램 목록에서 체크한 뒤 '선택 항목 담기'를 눌러 주세요." | Out-Null
        return
    }
    if ($script:WgUpdating) {
        Show-Msg "winget을 업데이트하는 중입니다. 끝난 뒤에 설치해 주세요." | Out-Null
        return
    }
    if ($script:HasWinget -eq $false -and @($selected | Where-Object { $_.App.Id -and -not $_.App.DirectOnly }).Count -gt 0) {
        Show-Msg "이 PC에서 winget을 찾을 수 없어 설치할 수 없습니다.`n`n왼쪽 아래 'winget 설치하기' 버튼으로 winget을 먼저 설치해 주세요." "winget 없음" 'OK' 'Warning' | Out-Null
        return
    }
    Stop-Export      # 보조 확인이 아직 돌고 있으면 정리 (설치와 winget 충돌 방지)
    Set-Busy $true
    $script:OkCount = 0; $script:FailCount = 0; $script:TotalCount = $selected.Count
    $script:installQueue.Clear()
    $script:runningJobs.Clear()
    $script:retryQueue.Clear()
    foreach ($e in $selected) {
        $e.Retried = $false; $e.IgnoreHash = $false; $e.SkipDeps = $false; $e.DirectFailed = $false
        $e.UseFallback = $false; $e.FallbackTried = $false
        Set-Status $e 'queued'; $script:installQueue.Enqueue($e)
    }
    $k = 1; foreach ($e in $selected) { Set-Stage $e "설치 대기 · ${k}번째 순서"; $k++ }
    $CartProg.Visibility = 'Visible'; $CartProg.Value = 0
    $CartHead.Text = "순차 설치 준비 중 · winget 목록을 동기화하는 중…"
    Write-Log "=== 설치 시작 (v$AppVersion, $($selected.Count)개, 한 번에 하나씩 순차 설치) ==="

    # winget 설치를 여러 개 동시에 돌리면 각자 패키지 소스(목록)를 따로 확인하면서
    # 중복 작업/잠금 충돌이 생길 수 있음 -> 시작 전에 한 번만 미리 동기화해둔다.
    # (화면이 멈추지 않게 백그라운드로 돌리고, 최대 30초만 기다리고 넘어감)
    Write-Log "winget 소스 동기화 중..."
    $SelText.Text = "소스 동기화 중…"
    try { $script:SyncProc = Start-Hidden "winget" "source update" } catch { $script:SyncProc = $null }
    $script:SyncDeadline = [DateTime]::Now.AddSeconds(30)
    $script:Phase = 'syncing'
})

# ───────────────────────────── 시작 ─────────────────────────────
$timer = New-Object System.Windows.Threading.DispatcherTimer
$timer.Interval = [TimeSpan]::FromMilliseconds(200)
$timer.Add_Tick({
    Poll-WingetCheck
    Poll-WgLatest
    Poll-WgUpdate
    Poll-Export
    Step-Install
})

$window.Add_Closing({ param($s, $ev)
    if ($script:Phase -ne 'idle') {
        $r = Show-Msg "설치가 진행 중입니다.`n창을 닫아도 이미 시작된 설치는 계속되지만, 남은 항목은 설치되지 않습니다.`n`n닫을까요?" "확인" 'YesNo' 'Warning'
        if ($r -ne 'Yes') { $ev.Cancel = $true }
    }
})

$window.Add_ContentRendered({
    Start-IconLoad
    Test-InstalledFromRegistry
    Start-InstalledCheck
    $timer.Start()
})

Set-Category '전체'
Update-CartUi
# PowerShell 에서 .NET 메서드 예외는 스크립트를 멈추지 않아, 여기서 실패하면 아무 표시 없이 꺼진다 -> 잡아서 알린다
try { [void]$window.ShowDialog() }
catch {
    $m = $_.Exception; while ($m.InnerException) { $m = $m.InnerException }
    Write-Log "창 표시 실패: $($m.GetType().Name): $($m.Message)"
    throw "창을 표시하지 못했습니다: $($m.GetType().Name): $($m.Message)"
}
$timer.Stop()
