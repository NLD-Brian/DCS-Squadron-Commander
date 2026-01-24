using System.Runtime.InteropServices;
using System.Runtime.Versioning;

namespace DCS_SC_Bridge
{
    [SupportedOSPlatform("windows")]
    public static class ConsoleHelper
    {
        [DllImport("kernel32.dll", SetLastError = true)]
        private static extern bool AllocConsole();

        [DllImport("kernel32.dll")]
        private static extern IntPtr GetConsoleWindow();

        [DllImport("user32.dll")]
        private static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);

        private const int SW_SHOW = 5;

        public static void ShowConsole()
        {
            try
            {
                var consoleWindowHandle = GetConsoleWindow();
                if (consoleWindowHandle == IntPtr.Zero)
                {
                    AllocConsole();
                }
                else
                {
                    ShowWindow(consoleWindowHandle, SW_SHOW);
                }
            }
            catch
            {
                // If console allocation fails, just continue without it
            }
        }
    }
}
