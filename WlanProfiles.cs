using System;
using System.Collections.Generic;
using System.ComponentModel;
using System.Runtime.InteropServices;

namespace Leenlaptop
{
    public static class WlanProfiles
    {
        [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
        private struct InterfaceInfo
        {
            public Guid Id;
            [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 256)] public string Description;
            public int State;
        }

        [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
        private struct ProfileInfo
        {
            [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 256)] public string Name;
            public uint Flags;
        }

        [DllImport("wlanapi.dll")] private static extern uint WlanOpenHandle(uint version, IntPtr reserved, out uint negotiated, out IntPtr handle);
        [DllImport("wlanapi.dll")] private static extern uint WlanCloseHandle(IntPtr handle, IntPtr reserved);
        [DllImport("wlanapi.dll")] private static extern uint WlanEnumInterfaces(IntPtr handle, IntPtr reserved, out IntPtr list);
        [DllImport("wlanapi.dll")] private static extern uint WlanGetProfileList(IntPtr handle, ref Guid id, IntPtr reserved, out IntPtr list);
        [DllImport("wlanapi.dll")] private static extern void WlanFreeMemory(IntPtr memory);
        [DllImport("wlanapi.dll", CharSet = CharSet.Unicode)]
        private static extern uint WlanDeleteProfile(IntPtr handle, ref Guid id, string name, IntPtr reserved);

        private static void Check(uint code)
        {
            if (code != 0) throw new Win32Exception((int)code);
        }

        public static string[] GetNames()
        {
            uint version;
            IntPtr handle;
            Check(WlanOpenHandle(2, IntPtr.Zero, out version, out handle));
            var names = new HashSet<string>(StringComparer.Ordinal);
            try
            {
                IntPtr interfaces;
                Check(WlanEnumInterfaces(handle, IntPtr.Zero, out interfaces));
                try
                {
                    int count = Marshal.ReadInt32(interfaces);
                    int size = Marshal.SizeOf(typeof(InterfaceInfo));
                    for (int i = 0; i < count; i++)
                    {
                        var info = (InterfaceInfo)Marshal.PtrToStructure(IntPtr.Add(interfaces, 8 + i * size), typeof(InterfaceInfo));
                        IntPtr profiles;
                        Check(WlanGetProfileList(handle, ref info.Id, IntPtr.Zero, out profiles));
                        try
                        {
                            int profileCount = Marshal.ReadInt32(profiles);
                            int profileSize = Marshal.SizeOf(typeof(ProfileInfo));
                            for (int p = 0; p < profileCount; p++)
                            {
                                var profile = (ProfileInfo)Marshal.PtrToStructure(IntPtr.Add(profiles, 8 + p * profileSize), typeof(ProfileInfo));
                                names.Add(profile.Name);
                            }
                        }
                        finally { WlanFreeMemory(profiles); }
                    }
                }
                finally { WlanFreeMemory(interfaces); }
            }
            finally { WlanCloseHandle(handle, IntPtr.Zero); }
            var result = new string[names.Count];
            names.CopyTo(result);
            return result;
        }

        public static int DeleteName(string name)
        {
            uint version;
            IntPtr handle;
            Check(WlanOpenHandle(2, IntPtr.Zero, out version, out handle));
            int removed = 0;
            try
            {
                IntPtr interfaces;
                Check(WlanEnumInterfaces(handle, IntPtr.Zero, out interfaces));
                try
                {
                    int count = Marshal.ReadInt32(interfaces);
                    int size = Marshal.SizeOf(typeof(InterfaceInfo));
                    for (int i = 0; i < count; i++)
                    {
                        var info = (InterfaceInfo)Marshal.PtrToStructure(IntPtr.Add(interfaces, 8 + i * size), typeof(InterfaceInfo));
                        IntPtr profiles;
                        Check(WlanGetProfileList(handle, ref info.Id, IntPtr.Zero, out profiles));
                        bool found = false;
                        try
                        {
                            int profileCount = Marshal.ReadInt32(profiles);
                            int profileSize = Marshal.SizeOf(typeof(ProfileInfo));
                            for (int p = 0; p < profileCount; p++)
                            {
                                var profile = (ProfileInfo)Marshal.PtrToStructure(IntPtr.Add(profiles, 8 + p * profileSize), typeof(ProfileInfo));
                                if (String.Equals(profile.Name, name, StringComparison.Ordinal)) found = true;
                            }
                        }
                        finally { WlanFreeMemory(profiles); }
                        if (found)
                        {
                            // WlanDeleteProfile gebruikt de letterlijke naam, zonder netsh-wildcards.
                            Check(WlanDeleteProfile(handle, ref info.Id, name, IntPtr.Zero));
                            removed++;
                        }
                    }
                }
                finally { WlanFreeMemory(interfaces); }
            }
            finally { WlanCloseHandle(handle, IntPtr.Zero); }
            return removed;
        }
    }
}
