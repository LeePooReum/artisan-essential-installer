#!/bin/bash
# 사용법: ./build.sh [출력파일명]
#   installer.ps1 + icons/*.png  ->  script.build.ps1 (아이콘 base64 내장)
#   Launcher.cs  + 위 스크립트(관리형 리소스) + 아이콘/매니페스트(.res)  ->  .NET EXE
#
# 예전 C 런처와 달리 임시 .ps1 을 떨어뜨리거나 powershell.exe 를 띄우지 않는다.
# EXE 안에서 PowerShell 엔진을 직접 불러 스크립트를 돌리므로 드로퍼류 오진을 줄인다.
set -e
cd "$(dirname "$0")"
OUT="${1:-필수프로그램설치도구.exe}"

# 1) 아이콘을 스크립트 안에 base64로 박아 script.build.ps1 생성
python3 - <<'EOF'
import base64, glob, os
s = open('installer.ps1', 'rb').read().decode('utf-8-sig').replace('\r\n', '\n')
lines = []
for f in sorted(glob.glob('icons/*.png')):
    key = os.path.basename(f)[:-4]
    b64 = base64.b64encode(open(f, 'rb').read()).decode()
    lines.append("$EmbeddedIcons['%s'] = '%s'" % (key.replace("'", "''"), b64))
marker = '# @@EMBEDDED_ICONS@@'
assert marker in s, 'marker missing'
s = s.replace(marker, '\n'.join(lines))
# PowerShell 5.1이 한글을 제대로 읽도록 UTF-8 BOM + CRLF
open('script.build.ps1', 'wb').write(b'\xef\xbb\xbf' + s.replace('\n', '\r\n').encode('utf-8'))
print('icons embedded:', len(lines))
EOF

# 2) 아이콘 + 관리자권한 매니페스트를 담은 Win32 리소스(.res)
x86_64-w64-mingw32-windres -c 65001 -O res launcher.rc launcher.res

# 3) .NET EXE 컴파일 (스크립트는 "script.ps1" 이라는 관리형 리소스로 넣음)
#    글꼴(Pretendard, OFL)은 ArtisanOS와 같은 이름의 관리형 리소스로 넣는다 (없으면 시스템 글꼴)
FONT_ARGS=""
for fn in Pretendard-Medium.otf Pretendard-Bold.otf Pretendard-Light.otf; do
    [ -f "Fonts/$fn" ] && FONT_ARGS="$FONT_ARGS -resource:Fonts/$fn,$fn"
done
mcs -sdk:4.5 -target:winexe -nologo \
    -win32res:launcher.res \
    -resource:script.build.ps1,script.ps1 $FONT_ARGS \
    -r:System.Windows.Forms.dll -r:System.Drawing.dll \
    -out:"$OUT" Launcher.cs

rm -f launcher.res
echo "빌드 완료: $OUT"
