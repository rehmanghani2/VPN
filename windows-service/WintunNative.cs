using System.Runtime.InteropServices;

namespace AntigravityVpnService;

/// <summary>
/// Wintun Native Driver API Interop (wintun.dll)
/// Wintun is the official WireGuard high-performance kernel TUN driver on Windows.
/// </summary>
public static class WintunNative
{
    private const string WintunDll = "wintun.dll";

    public const uint WINTUN_MIN_RING_CAPACITY = 0x20000;    // 128 KiB
    public const uint WINTUN_MAX_RING_CAPACITY = 0x4000000;  // 64 MiB

    [StructLayout(LayoutKind.Sequential)]
    public struct GUID
    {
        public uint Data1;
        public ushort Data2;
        public ushort Data3;
        [MarshalAs(UnmanagedType.ByValArray, SizeConst = 8)]
        public byte[] Data4;

        public static GUID FromGuid(Guid guid)
        {
            var bytes = guid.ToByteArray();
            return new GUID
            {
                Data1 = BitConverter.ToUInt32(bytes, 0),
                Data2 = BitConverter.ToUInt16(bytes, 4),
                Data3 = BitConverter.ToUInt16(bytes, 6),
                Data4 = bytes.Skip(8).Take(8).ToArray()
            };
        }
    }

    [DllImport(WintunDll, EntryPoint = "WintunCreateAdapter", SetLastError = true, CharSet = CharSet.Unicode)]
    public static extern IntPtr WintunCreateAdapter(
        [MarshalAs(UnmanagedType.LPWStr)] string name,
        [MarshalAs(UnmanagedType.LPWStr)] string tunnelType,
        ref GUID requestedGuid);

    [DllImport(WintunDll, EntryPoint = "WintunOpenAdapter", SetLastError = true, CharSet = CharSet.Unicode)]
    public static extern IntPtr WintunOpenAdapter([MarshalAs(UnmanagedType.LPWStr)] string name);

    [DllImport(WintunDll, EntryPoint = "WintunCloseAdapter")]
    public static extern void WintunCloseAdapter(IntPtr adapter);

    [DllImport(WintunDll, EntryPoint = "WintunDeleteDriver")]
    public static extern bool WintunDeleteDriver();

    [DllImport(WintunDll, EntryPoint = "WintunGetAdapterLUID")]
    public static extern void WintunGetAdapterLUID(IntPtr adapter, out ulong luid);

    [DllImport(WintunDll, EntryPoint = "WintunStartSession", SetLastError = true)]
    public static extern IntPtr WintunStartSession(IntPtr adapter, uint capacity);

    [DllImport(WintunDll, EntryPoint = "WintunEndSession")]
    public static extern void WintunEndSession(IntPtr session);

    [DllImport(WintunDll, EntryPoint = "WintunGetReadWaitEvent")]
    public static extern IntPtr WintunGetReadWaitEvent(IntPtr session);
}
