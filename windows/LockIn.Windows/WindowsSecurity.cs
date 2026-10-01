using System.Runtime.InteropServices;
using System.Security.Principal;
using System.Windows;
namespace LockIn;
public static class WindowsSecurity {
 [StructLayout(LayoutKind.Sequential,CharSet=CharSet.Unicode)]struct CredUI {public int Size;public IntPtr Parent;public string Message;public string Caption;public IntPtr Banner;}
 [DllImport("credui.dll",CharSet=CharSet.Unicode)]static extern int CredUIPromptForCredentialsW(ref CredUI ui,string target,IntPtr reserved,int error,StringBuilder user,int maxUser,StringBuilder password,int maxPassword,ref bool save,int flags);
 [DllImport("advapi32.dll",CharSet=CharSet.Unicode,SetLastError=true)]static extern bool LogonUserW(string user,string domain,StringBuilder password,int type,int provider,out IntPtr token);
 [DllImport("kernel32.dll")]static extern bool CloseHandle(IntPtr handle);
 [StructLayout(LayoutKind.Sequential)]struct Blob {public int Size;public IntPtr Data;}
 [DllImport("crypt32.dll",CharSet=CharSet.Unicode,SetLastError=true)]static extern bool CryptProtectData(ref Blob input,string description,IntPtr entropy,IntPtr reserved,IntPtr prompt,int flags,out Blob output);
 [DllImport("crypt32.dll",CharSet=CharSet.Unicode,SetLastError=true)]static extern bool CryptUnprotectData(ref Blob input,IntPtr description,IntPtr entropy,IntPtr reserved,IntPtr prompt,int flags,out Blob output);
 [DllImport("kernel32.dll")]static extern IntPtr LocalFree(IntPtr memory);
 public static bool Verify(Window owner) {
  var account=WindowsIdentity.GetCurrent().Name;var user=new StringBuilder(account,513);var password=new StringBuilder(256);var save=false;
  var ui=new CredUI{Size=Marshal.SizeOf<CredUI>(),Parent=new System.Windows.Interop.WindowInteropHelper(owner).Handle,Message="Verify your Windows account password for Nuclear Mode. Your Windows Hello PIN is not your account password.",Caption="LockIn · Nuclear verification"};
  try {
   var code=CredUIPromptForCredentialsW(ref ui,"LockIn Nuclear verification",IntPtr.Zero,0,user,513,password,256,ref save,0x40000|0x2|0x80|0x100000);
   if(code!=0)return false;
   if(!string.Equals(user.ToString(),account,StringComparison.OrdinalIgnoreCase))throw new InvalidOperationException("Use the currently signed-in Windows account.");
   var parts=account.Split('\\',2);var name=parts.Length==2?parts[1]:account;var domain=parts.Length==2?parts[0]:".";
   if(!LogonUserW(name,domain,password,2,0,out var token))throw new InvalidOperationException("Windows could not verify this account password. Check the password or account sign-in policy; Nuclear remains off.");
   try {using var authenticated=new WindowsIdentity(token);return authenticated.User==WindowsIdentity.GetCurrent().User;}finally{CloseHandle(token);}
  }finally{for(int i=0;i<password.Length;i++)password[i]='\0';password.Clear();}
 }
 public static byte[] Protect(byte[] bytes,bool encrypt) {
  var input=new Blob{Size=bytes.Length,Data=Marshal.AllocHGlobal(bytes.Length)};Blob output=default;
  try {Marshal.Copy(bytes,0,input.Data,bytes.Length);var success=encrypt?CryptProtectData(ref input,"LockIn browser credentials",IntPtr.Zero,IntPtr.Zero,IntPtr.Zero,1,out output):CryptUnprotectData(ref input,IntPtr.Zero,IntPtr.Zero,IntPtr.Zero,IntPtr.Zero,1,out output);if(!success)throw new InvalidOperationException("Windows credential protection failed.");var result=new byte[output.Size];Marshal.Copy(output.Data,result,0,result.Length);return result;}
  finally{for(int i=0;i<input.Size;i++)Marshal.WriteByte(input.Data,i,0);Marshal.FreeHGlobal(input.Data);if(output.Data!=IntPtr.Zero)LocalFree(output.Data);}
 }
}
