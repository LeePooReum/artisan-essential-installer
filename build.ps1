# 필수 프로그램 설치 도구 - Windows용 빌드 스크립트
# 사용법 (PowerShell 5.1 이상):
#   powershell -ExecutionPolicy Bypass -File .\build.ps1 [-Out "필수프로그램설치도구_v2.0_정식판.exe"]
#
# build.sh(리눅스: mono mcs + mingw windres)와 같은 결과물을 Windows 기본 C# 컴파일러(csc.exe, .NET Framework 4.x)로 만든다.
#   1) installer.ps1 + icons\*.png  ->  script.build.ps1  (아이콘을 base64로 내장, UTF-8 BOM + CRLF)
#   2) Launcher.cs + script.build.ps1(관리형 리소스 "script.ps1") + app.ico + app.manifest  ->  EXE
# csc.exe 는 /win32icon, /win32manifest 를 직접 받으므로 .res 파일이 필요 없다.
param([string]$Out = '필수프로그램설치도구_v2.0_정식판.exe')
$ErrorActionPreference = 'Stop'
Set-Location -LiteralPath $PSScriptRoot

# 1) 아이콘 내장 스크립트 생성 (build.sh 의 파이썬 단계와 동일한 결과)
$src = [IO.File]::ReadAllText((Join-Path $PSScriptRoot 'installer.ps1'), [Text.Encoding]::UTF8)
$src = $src.TrimStart([char]0xFEFF).Replace("`r`n", "`n")
$marker = '# @@EMBEDDED_ICONS@@'
if (-not $src.Contains($marker)) { throw "installer.ps1 에 $marker 표시가 없습니다." }
$files = @(Get-ChildItem -LiteralPath (Join-Path $PSScriptRoot 'icons') -Filter *.png)
[string[]]$names = $files | ForEach-Object { $_.Name }
[Array]::Sort($names, [StringComparer]::Ordinal)   # build.sh(파이썬 sorted)와 같은 순서
$lines = foreach ($n in $names) {
    $f = Get-Item -LiteralPath (Join-Path (Join-Path $PSScriptRoot 'icons') $n)
    $key = $f.BaseName.Replace("'", "''")
    "`$EmbeddedIcons['$key'] = '$([Convert]::ToBase64String([IO.File]::ReadAllBytes($f.FullName)))'"
}
$src = $src.Replace($marker, ($lines -join "`n")).Replace("`n", "`r`n")
[IO.File]::WriteAllText((Join-Path $PSScriptRoot 'script.build.ps1'), $src, (New-Object Text.UTF8Encoding($true)))
Write-Host "icons embedded: $(@($lines).Count)"

# 2) 문법 검사 (빌드 전에 PowerShell 파서로 확인)
$tok = $null; $err = $null
[void][Management.Automation.Language.Parser]::ParseFile((Join-Path $PSScriptRoot 'script.build.ps1'), [ref]$tok, [ref]$err)
if ($err.Count -gt 0) { $err | ForEach-Object { Write-Host "$($_.Extent.StartLineNumber): $($_.Message)" -ForegroundColor Red }; throw "PowerShell 문법 오류 $($err.Count)개" }

# 3) 컴파일
$csc = Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
if (-not (Test-Path $csc)) { $csc = Join-Path $env:WINDIR 'Microsoft.NET\Framework\v4.0.30319\csc.exe' }
if (-not (Test-Path $csc)) { throw 'csc.exe(.NET Framework 4.x)를 찾을 수 없습니다.' }
# 글꼴(Pretendard, OFL): ArtisanOS와 같은 방식으로 EXE에 넣고, 실행 시 %LOCALAPPDATA%\ArtisanOS\Fonts 에 풀어 쓴다
$fontArgs = @(foreach ($fn in 'Pretendard-Medium.otf', 'Pretendard-Bold.otf', 'Pretendard-Light.otf') {
    $fp = Join-Path (Join-Path $PSScriptRoot 'Fonts') $fn
    if (Test-Path -LiteralPath $fp) { "/resource:$fp,$fn" } else { Write-Host "글꼴 없음(시스템 글꼴 사용): $fn" -ForegroundColor Yellow }
})
& $csc /nologo /target:winexe /codepage:65001 /optimize+ `
    "/win32icon:app.ico" "/win32manifest:app.manifest" `
    "/resource:script.build.ps1,script.ps1" $fontArgs `
    /r:System.Windows.Forms.dll /r:System.Drawing.dll `
    "/out:$Out" Launcher.cs
if ($LASTEXITCODE -ne 0) { throw "csc 실패 (종료코드 $LASTEXITCODE)" }
Write-Host "빌드 완료: $Out"
