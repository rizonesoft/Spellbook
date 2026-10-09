// Native boundaries for the isolated UI driver, not production app code.
using System;
using System.Collections.Generic;
using System.ComponentModel;
using System.Runtime.InteropServices;

namespace Spellbook.UiTesting
{
    public static class Native
    {
        [StructLayout(LayoutKind.Sequential)]
        public struct Rect { public int Left, Top, Right, Bottom; }
        [StructLayout(LayoutKind.Sequential)]
        private struct HighContrast { public uint Size, Flags; public IntPtr Scheme; }
        [StructLayout(LayoutKind.Sequential)]
        private struct Keyboard { public ushort Key, Scan; public uint Flags, Time; public UIntPtr Extra; }
        [StructLayout(LayoutKind.Explicit)]
        private struct InputUnion { [FieldOffset(0)] public Keyboard Keyboard; [FieldOffset(0)] public Mouse Mouse; }
        [StructLayout(LayoutKind.Sequential)]
        private struct Mouse { public int X, Y; public uint Data, Flags, Time; public UIntPtr Extra; }
        [StructLayout(LayoutKind.Sequential)]
        private struct Input { public uint Type; public InputUnion Value; }

        [DllImport("user32.dll", SetLastError=true)] public static extern bool GetWindowRect(IntPtr window, out Rect rect);
        [DllImport("user32.dll")] public static extern uint GetDpiForWindow(IntPtr window);
        [DllImport("user32.dll", SetLastError=true)] public static extern IntPtr SetThreadDpiAwarenessContext(IntPtr context);
        [DllImport("user32.dll", SetLastError=true)] public static extern bool PrintWindow(IntPtr window, IntPtr dc, uint flags);
        [DllImport("user32.dll")] public static extern bool IsWindow(IntPtr window);
        [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr window);
        [DllImport("user32.dll")] public static extern bool IsIconic(IntPtr window);
        [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
        [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr window);
        [DllImport("user32.dll")] private static extern uint GetWindowThreadProcessId(IntPtr window, out uint process);
        [DllImport("user32.dll")] private static extern short GetAsyncKeyState(int key);
        [DllImport("user32.dll", SetLastError=true)] private static extern uint SendInput(uint count, Input[] inputs, int size);
        [DllImport("user32.dll", EntryPoint="SystemParametersInfoW", SetLastError=true)]
        private static extern bool SystemParametersInfo(uint action, uint parameter, ref HighContrast value, uint flags);

        public static int ProcessId(IntPtr window)
        {
            uint process;
            if (GetWindowThreadProcessId(window, out process) == 0) throw new Win32Exception("Cannot identify window owner");
            return checked((int)process);
        }

        public static void VerifyWindow(IntPtr window, int process)
        {
            if (window == IntPtr.Zero || !IsWindow(window) || ProcessId(window) != process)
                throw new InvalidOperationException("Window does not belong to the launched process");
            if (!IsWindowVisible(window) || IsIconic(window))
                throw new InvalidOperationException("Window is hidden or minimized");
        }

        public static bool HighContrastEnabled()
        {
            var value = new HighContrast();
            value.Size = (uint)Marshal.SizeOf<HighContrast>();
            if (!SystemParametersInfo(0x42, value.Size, ref value, 0)) throw new Win32Exception();
            return (value.Flags & 1) != 0;
        }

        private static Input Key(ushort key, ushort scan, uint flags)
        {
            return new Input { Type=1, Value=new InputUnion { Keyboard=new Keyboard { Key=key, Scan=scan, Flags=flags } } };
        }

        private static void VerifyInputTarget(IntPtr window, int process)
        {
            VerifyWindow(window, process);
            if (GetForegroundWindow() != window) throw new InvalidOperationException("Owned window is not foreground; no input sent");
            foreach (int key in new[] { 16, 17, 18, 91, 92 })
                if ((GetAsyncKeyState(key) & 0x8000) != 0)
                    throw new InvalidOperationException("A user modifier is held; no input sent");
        }

        private static void Send(IntPtr window, int process, Input[] inputs)
        {
            VerifyInputTarget(window, process);
            uint count = SendInput((uint)inputs.Length, inputs, Marshal.SizeOf<Input>());
            if (count != inputs.Length)
            {
                // Release only keys this call actually pressed, never held user modifiers.
                var pressed = new Dictionary<string, Keyboard>();
                for (int i=0; i<count; ++i)
                {
                    var key = inputs[i].Value.Keyboard;
                    string id = key.Key.ToString() + ":" + key.Scan.ToString();
                    if ((key.Flags & 2) == 0) pressed[id] = key; else pressed.Remove(id);
                }
                var releases = new List<Input>();
                foreach (var key in pressed.Values) releases.Add(Key(key.Key, key.Scan, key.Flags | 2));
                if (releases.Count != 0) SendInput((uint)releases.Count, releases.ToArray(), Marshal.SizeOf<Input>());
                throw new InvalidOperationException("SendInput inserted only " + count + " of " + inputs.Length + " events");
            }
            if (GetForegroundWindow() != window) throw new InvalidOperationException("Focus changed during input; result requires inspection");
        }

        public static void SendChord(IntPtr window, int process, ushort[] keys)
        {
            if (keys.Length == 0 || keys.Length > 4) throw new ArgumentException("Invalid chord");
            var inputs = new List<Input>();
            foreach (ushort key in keys)
            {
                if ((GetAsyncKeyState(key) & 0x8000) != 0) throw new InvalidOperationException("A requested key is already held");
                inputs.Add(Key(key, 0, 0));
            }
            for (int i=keys.Length-1; i>=0; --i) inputs.Add(Key(keys[i], 0, 2));
            Send(window, process, inputs.ToArray());
        }

        public static void SendText(IntPtr window, int process, string text)
        {
            if (text.Length == 0 || text.Length > 4096) throw new ArgumentException("Text input length must be 1 to 4096 UTF-16 units");
            var inputs = new List<Input>();
            foreach (char value in text) { inputs.Add(Key(0, value, 4)); inputs.Add(Key(0, value, 6)); }
            Send(window, process, inputs.ToArray());
        }
    }
}
