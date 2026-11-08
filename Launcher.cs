// 필수 프로그램 설치 도구 - .NET 런처
//
// 예전 런처(C)는 스크립트를 임시 폴더에 풀고 "powershell.exe -ExecutionPolicy Bypass -WindowStyle Hidden"으로
// 실행했다. 이 "파일을 떨어뜨린 뒤 숨은 powershell로 실행"하는 모양이 드로퍼류와 똑같아서
// 백신 ML 엔진이 추측으로 오진하는 주된 원인이었다.
// 이 런처는 임시 파일도, powershell.exe 실행도 없이 EXE 안에서 PowerShell 엔진을 직접 불러 스크립트를 돌린다.
//   - 스크립트: 관리형 리소스 "script.ps1" (평문 UTF-8, 아이콘은 스크립트 안에 base64로 들어있음)
//   - System.Management.Automation 은 Windows에 기본으로 깔려있는 것을 실행 시점에 불러온다.
// 관리자 권한은 EXE에 박힌 매니페스트(requireAdministrator)로 시작할 때 한 번만 받는다.
using System;
using System.IO;
using System.Reflection;
using System.Text;
using System.Threading;
using System.Windows.Forms;

[assembly: AssemblyTitle("필수 프로그램 설치 도구")]
[assembly: AssemblyDescription("winget으로 자주 쓰는 프로그램을 골라 설치하는 도구")]
[assembly: AssemblyProduct("필수 프로그램 설치 도구")]
[assembly: AssemblyCompany("Artisan Lab")]
[assembly: AssemblyCopyright("Artisan Lab")]
[assembly: AssemblyVersion("2.0.0.0")]
[assembly: AssemblyFileVersion("2.0.0.0")]
[assembly: AssemblyInformationalVersion("2.0.0")]

static class Launcher
{
    const string Title = "필수 프로그램 설치 도구";
    const string SmaName = "System.Management.Automation, Version=3.0.0.0, Culture=neutral, PublicKeyToken=31bf3856ad364e35";

    [STAThread]
    static int Main()
    {
        try
        {
            var self = Assembly.GetExecutingAssembly();
            string exePath = self.Location;
            Environment.SetEnvironmentVariable("PI_SCRIPT_DIR", Path.GetDirectoryName(exePath) + "\\");
            Environment.SetEnvironmentVariable("PI_EXE_PATH", exePath);

            string script;
            using (var s = self.GetManifestResourceStream("script.ps1"))
            {
                if (s == null) { Fail("내장된 설치 스크립트를 찾을 수 없습니다."); return 1; }
                using (var r = new StreamReader(s, Encoding.UTF8)) script = r.ReadToEnd();
            }

            return RunScript(script);
        }
        catch (Exception ex)
        {
            Fail("실행 중 오류가 발생했습니다.\n\n" + Unwrap(ex).Message);
            return 1;
        }
    }

    // PowerShell 엔진을 이 프로세스(STA 메인 스레드) 안에서 직접 실행.
    // SMA 어셈블리를 컴파일 때가 아니라 실행 때 불러오므로(리플렉션) Windows의 것을 그대로 쓴다.
    static int RunScript(string script)
    {
        Assembly sma = null;
        try { sma = Assembly.Load(SmaName); }
        catch
        {
            // 버전이 다른 환경을 대비한 대체 경로 (GAC에서 이름으로 찾음)
            try { sma = Assembly.Load("System.Management.Automation"); }
            catch { }
        }
        if (sma == null)
        {
            Fail("Windows PowerShell 구성 요소를 찾을 수 없습니다.\nWindows PowerShell 5.1이 설치되어 있어야 합니다.");
            return 1;
        }

        Type tIss = sma.GetType("System.Management.Automation.Runspaces.InitialSessionState", true);
        Type tRsf = sma.GetType("System.Management.Automation.Runspaces.RunspaceFactory", true);
        Type tRs  = sma.GetType("System.Management.Automation.Runspaces.Runspace", true);
        Type tOpt = sma.GetType("System.Management.Automation.Runspaces.PSThreadOptions", true);
        Type tPs  = sma.GetType("System.Management.Automation.PowerShell", true);
        Type tPol = sma.GetType("Microsoft.PowerShell.ExecutionPolicy", true);

        object iss = tIss.GetMethod("CreateDefault", Type.EmptyTypes).Invoke(null, null);
        // 이 프로세스 안에서만 적용 (시스템 실행 정책은 건드리지 않음)
        tIss.GetProperty("ExecutionPolicy").SetValue(iss, Enum.Parse(tPol, "Bypass"), null);

        object rs = tRsf.GetMethod("CreateRunspace", new[] { tIss }).Invoke(null, new[] { iss });
        tRs.GetProperty("ApartmentState").SetValue(rs, ApartmentState.STA, null);        // WPF 창은 STA 필요
        tRs.GetProperty("ThreadOptions").SetValue(rs, Enum.Parse(tOpt, "UseCurrentThread"), null);
        tRs.GetMethod("Open", Type.EmptyTypes).Invoke(rs, null);

        object ps = tPs.GetMethod("Create", Type.EmptyTypes).Invoke(null, null);
        try
        {
            tPs.GetProperty("Runspace").SetValue(ps, rs, null);
            tPs.GetMethod("AddScript", new[] { typeof(string) }).Invoke(ps, new object[] { script });
            try
            {
                // PowerShell.Invoke() 는 일반 버전과 Invoke<T>() 제네릭 버전이 모두 인자가 없어서
                // GetMethod 로는 모호해진다 → 제네릭이 아닌 인자 없는 Invoke 를 직접 골라낸다.
                MethodInfo invoke = null;
                foreach (MethodInfo m in tPs.GetMethods(BindingFlags.Public | BindingFlags.Instance))
                {
                    if (m.Name == "Invoke" && !m.IsGenericMethodDefinition && m.GetParameters().Length == 0)
                    { invoke = m; break; }
                }
                if (invoke == null) throw new MissingMethodException("PowerShell.Invoke");
                invoke.Invoke(ps, null);
            }
            catch (Exception ex)
            {
                // 창을 띄우기도 전에 터진 경우에만 의미가 있다 (스크립트 자체 오류는 창 안에서 처리됨)
                Exception u = Unwrap(ex);
                Fail("설치 도구를 시작하지 못했습니다.\n\n" + u.GetType().Name + ": " + u.Message
                     + (u.InnerException != null ? "\n" + u.InnerException.Message : ""));
                return 1;
            }
            return 0;
        }
        finally
        {
            ((IDisposable)ps).Dispose();
            ((IDisposable)rs).Dispose();
        }
    }

    static Exception Unwrap(Exception ex)
    {
        while (ex is TargetInvocationException && ex.InnerException != null) ex = ex.InnerException;
        return ex;
    }

    static void Fail(string msg)
    {
        MessageBox.Show(msg, Title, MessageBoxButtons.OK, MessageBoxIcon.Error);
    }
}
