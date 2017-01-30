function Get-LocalRight {
<#
*Privilege names are **case-sensitive**.* Valid privileges are documented on Microsoft's website: 
[Privilege Constants]    (http://msdn.microsoft.com/en-us/library/windows/desktop/bb530716.aspx)
[Account Right Constants](http://msdn.microsoft.com/en-us/library/windows/desktop/bb545671.aspx)

.EXAMPLE
Get-LocalRight -SecurityRight SeInteractiveLogonRight
#>

[cmdletbinding()]
Param (
    [validateset('SeAssignPrimaryTokenPrivilege','SeAuditPrivilege','SeBackupPrivilege','SeBatchLogonRight',
    'SeChangeNotifyPrivilege','SeCreateGlobalPrivilege','SeCreatePagefilePrivilege','SeCreatePermanentPrivilege',
    'SeCreateSymbolicLinkPrivilege','SeCreateTokenPrivilege','SeDebugPrivilege','SeDenyBatchLogonRight',
    'SeDenyInteractiveLogonRight','SeDenyNetworkLogonRight','SeDenyRemoteInteractiveLogonRight',
    'SeDenyServiceLogonRight','SeEnableDelegationPrivilege','SeImpersonatePrivilege',
    'SeIncreaseBasePriorityPrivilege','SeIncreaseQuotaPrivilege','SeIncreaseWorkingSetPrivilege',
    'SeInteractiveLogonRight','SeLoadDriverPrivilege','SeLockMemoryPrivilege','SeMachineAccountPrivilege',
    'SeManageVolumePrivilege','SeNetworkLogonRight','SeProfileSingleProcessPrivilege','SeRelabelPrivilege',
    'SeRemoteInteractiveLogonRight','SeRemoteShutdownPrivilege','SeRestorePrivilege','SeSecurityPrivilege',
    'SeServiceLogonRight','SeShutdownPrivilege','SeSyncAgentPrivilege','SeSystemEnvironmentPrivilege',
    'SeSystemProfilePrivilege','SeSystemtimePrivilege','SeTakeOwnershipPrivilege','SeTcbPrivilege',
    'SeTimeZonePrivilege','SeTrustedCredManAccessPrivilege','SeUndockPrivilege','SeUnsolicitedInputPrivilege')]

    [String[]]$SecurityRight = ('SeTcbPrivilege','SeInteractiveLogonRight','SeRemoteInteractiveLogonRight','SeBackupPrivilege',
                                'SeSystemtimePrivilege','SeCreateTokenPrivilege','SeDebugPrivilege',
                                'SeEnableDelegationPrivilege','SeLoadDriverPrivilege','SeBatchLogonRight',
                                'SeServiceLogonRight','SeSecurityPrivilege','SeSystemEnvironmentPrivilege',
                                'SeManageVolumePrivilege','SeRestorePrivilege','SeSyncAgentPrivilege','SeRelabelPrivilege',
                                'SeTakeOwnershipPrivilege')
)

$c = @'
using System;
using System.Runtime.InteropServices;
using System.Security;
using System.Security.Principal;
using System.ComponentModel;

namespace LsaSecurity
{
    using LSA_HANDLE = IntPtr;

    class Program
    {
        static void Main(string[] args)
        {
            using (LsaSecurity.LsaWrapper lsa = new LsaSecurity.LsaWrapper())
            {
                Console.WriteLine("Enter the right");
                string p = Console.ReadLine();
                Console.WriteLine(p);
                System.Security.Principal.SecurityIdentifier[] result = lsa.ReadPrivilege(p);
                foreach (SecurityIdentifier i in result)
                {
                    string a = i.ToString();
                    Console.WriteLine(a);

                }
                Console.ReadLine();
            }
        }
    }


    [StructLayout(LayoutKind.Sequential)]
    public struct LSA_OBJECT_ATTRIBUTES
    {
        public int Length;
        public LSA_HANDLE RootDirectory;
        public LSA_HANDLE ObjectName;
        public int Attributes;
        public LSA_HANDLE SecurityDescriptor;
        public LSA_HANDLE SecurityQualityOfService;
    }

    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
    public struct LSA_UNICODE_STRING
    {
        public ushort Length;
        public ushort MaximumLength;
        [MarshalAs(UnmanagedType.LPWStr)]
        public string Buffer;
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct LSA_ENUMERATION_INFORMATION
    {
        public LSA_HANDLE PSid;
    }

    sealed public class Win32Sec
    {
        [DllImport("advapi32", CharSet = CharSet.Unicode, SetLastError = true),
                   SuppressUnmanagedCodeSecurityAttribute]
        public static extern uint LsaOpenPolicy(LSA_UNICODE_STRING[] SystemName,
                                                ref LSA_OBJECT_ATTRIBUTES ObjectAttributes,
                                                int AccessMask,
                                                out LSA_HANDLE PolicyHandle);

        [DllImport("advapi32", CharSet = CharSet.Unicode, SetLastError = true),
                   SuppressUnmanagedCodeSecurityAttribute]
        public static extern long LsaEnumerateAccountsWithUserRight(LSA_HANDLE PolicyHandle,
                                                                    LSA_UNICODE_STRING[] UserRights,
                                                                    out LSA_HANDLE EnumerationBuffer,
                                                                    out int CountReturned);

        [DllImport("advapi32")]
        public static extern int LsaNtStatusToWinError(int NTSTATUS);

        [DllImport("advapi32")]
        public static extern int LsaClose(LSA_HANDLE PolicyHandle);

        [DllImport("advapi32")]
        public static extern int LsaFreeMemory(LSA_HANDLE Buffer);
    }

    public class LsaWrapper : IDisposable
    {
        public enum Access : int
        {
            POLICY_READ = 0x20006,
            POLICY_ALL_ACCESS = 0x00F0FFF,
            POLICY_EXECUTE = 0X20801,
            POLICY_WRITE = 0X207F8
        }

        const uint STATUS_ACCESS_DENIED = 0xc0000022;
        const uint STATUS_INSUFFICIENT_RESOURCES = 0xc000009a;
        const uint STATUS_NO_MEMORY = 0xc0000017;
        const uint STATUS_NO_MORE_ENTRIES = 0xc000001A;

        LSA_HANDLE lsaHandle;

        public LsaWrapper()
            : this(null)
        { }

        // local system if systemName is null
        public LsaWrapper(string systemName)
        {
            LSA_OBJECT_ATTRIBUTES lsaAttr;
            lsaAttr.RootDirectory = LSA_HANDLE.Zero;
            lsaAttr.ObjectName = LSA_HANDLE.Zero;
            lsaAttr.Attributes = 0;
            lsaAttr.SecurityDescriptor = LSA_HANDLE.Zero;
            lsaAttr.SecurityQualityOfService = LSA_HANDLE.Zero;
            lsaAttr.Length = Marshal.SizeOf(typeof(LSA_OBJECT_ATTRIBUTES));
            lsaHandle = LSA_HANDLE.Zero;

            LSA_UNICODE_STRING[] system = null;

            if (systemName != null)
            {
                system = new LSA_UNICODE_STRING[1];
                system[0] = InitLsaString(systemName);
            }

            uint ret = Win32Sec.LsaOpenPolicy(system, ref lsaAttr,
                                              (int)Access.POLICY_ALL_ACCESS,
                                              out lsaHandle);
            if (ret == 0) { return; }

            if (ret == STATUS_ACCESS_DENIED)
            {
                throw new UnauthorizedAccessException();
            }
            if ((ret == STATUS_INSUFFICIENT_RESOURCES) || (ret == STATUS_NO_MEMORY))
            {
                throw new OutOfMemoryException();
            }
            throw new Win32Exception(Win32Sec.LsaNtStatusToWinError((int)ret));
        }

        public SecurityIdentifier[] ReadPrivilege(string privilege)
        {
            LSA_UNICODE_STRING[] privileges = new LSA_UNICODE_STRING[1];
            privileges[0] = InitLsaString(privilege);
            LSA_HANDLE buffer;
            int count = 0;
            long ret = Win32Sec.LsaEnumerateAccountsWithUserRight(lsaHandle, privileges, out buffer, out count);

            if (ret == 0)
            {
                SecurityIdentifier[] sids = new SecurityIdentifier[count];

                for (long i = 0, elemOffs = (long)buffer; i < count; i++)
                {
                    LSA_ENUMERATION_INFORMATION lsaInfo = (LSA_ENUMERATION_INFORMATION)Marshal.PtrToStructure(
                        (LSA_HANDLE)elemOffs, typeof(LSA_ENUMERATION_INFORMATION));

                    sids[i] = new SecurityIdentifier(lsaInfo.PSid);

                    elemOffs += Marshal.SizeOf(typeof(LSA_ENUMERATION_INFORMATION));
                }

                return sids;
            }

            if (ret == STATUS_ACCESS_DENIED)
            {
                throw new UnauthorizedAccessException();
            }
            if ((ret == STATUS_INSUFFICIENT_RESOURCES) || (ret == STATUS_NO_MEMORY))
            {
                throw new OutOfMemoryException();
            }

            throw new Win32Exception(Win32Sec.LsaNtStatusToWinError((int)ret));
        }

        public void Dispose()
        {
            if (lsaHandle != LSA_HANDLE.Zero)
            {
                Win32Sec.LsaClose(lsaHandle);
                lsaHandle = LSA_HANDLE.Zero;
            }
            GC.SuppressFinalize(this);
        }

        ~LsaWrapper()
        {
            Dispose();
        }

        public static LSA_UNICODE_STRING InitLsaString(string s)
        {
            // Unicode strings max. 32KB
            if (s.Length > 0x7ffe)
                throw new ArgumentException("String too long");
            LSA_UNICODE_STRING lus = new LSA_UNICODE_STRING();
            lus.Buffer = s;
            lus.Length = (ushort)(s.Length * sizeof(char));
            lus.MaximumLength = (ushort)(lus.Length + sizeof(char));
            return lus;
        }
    }
}
'@

    try {
        $t = [LsaSecurity.LsaWrapper]
    }
    catch {
       $t = Add-Type -TypeDefinition $c 
    }

    $d = New-Object -TypeName LsaSecurity.LsaWrapper
    
    
    $SecurityRight | Foreach-Object {
        $Right = $_
        try {
            $d.ReadPrivilege($Right) | ForEach-Object {
                
                $Current = $_.Translate([System.Security.Principal.NTAccount])

                New-Object -TypeName psobject -Property @{
                    SecurityRight= $Right
                    Identity     = $Current.value
                }
            }
        }
        Catch {
            Write-Warning -Message "No Identites with $Right"
        }
    }
}