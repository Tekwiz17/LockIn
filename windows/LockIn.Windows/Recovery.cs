using System.Diagnostics;
using Microsoft.Win32;
namespace LockIn;
public static class Recovery {
 static string FilePath=>Path.Combine(Engine.DirectoryPath,"watchdog.json");
 public sealed class Lease {public int Pid {get;set;}public long Started {get;set;}public DateTimeOffset Expires {get;set;}}
 static Process? watcher;
 public static void Update(Engine engine){
  var active=engine.Data.Session!=null;using var key=Registry.CurrentUser.CreateSubKey(@"Software\Microsoft\Windows\CurrentVersion\Run");
  if(!active){key.DeleteValue("LockIn Session Recovery",false);if(File.Exists(FilePath))File.Delete(FilePath);return;}
  using var self=Process.GetCurrentProcess();var lease=new Lease{Pid=Environment.ProcessId,Started=self.StartTime.ToUniversalTime().Ticks,Expires=DateTimeOffset.UtcNow.AddSeconds(45)};
  var tmp=FilePath+".tmp";File.WriteAllText(tmp,JsonSerializer.Serialize(lease,Engine.Json));File.Move(tmp,FilePath,true);
  var exe=Environment.ProcessPath!;key.SetValue("LockIn Session Recovery",$"\"{exe}\" --recovery-background");
  if(watcher==null||watcher.HasExited){watcher?.Dispose();watcher=Process.Start(new ProcessStartInfo(exe,"--watchdog"){UseShellExecute=false,CreateNoWindow=true});}
 }
 public static void Watch(){
  using var mutex=new System.Threading.Mutex(true,"Local\\LockInWatchdog-"+System.Security.Principal.WindowsIdentity.GetCurrent().User!.Value,out var acquired);if(!acquired)return;
  while(true){try{
   if(!File.Exists(FilePath))break;var lease=JsonSerializer.Deserialize<Lease>(File.ReadAllText(FilePath),Engine.Json);if(lease==null)break;
   var state=File.Exists(Engine.StatePath)?JsonSerializer.Deserialize<SavedState>(File.ReadAllText(Engine.StatePath),Engine.Json):null;
   if(state?.Session==null)break;
   bool running=false;try{using var process=Process.GetProcessById(lease.Pid);running=!process.HasExited&&process.StartTime.ToUniversalTime().Ticks==lease.Started;}catch{}
   if(!running){Process.Start(new ProcessStartInfo(Environment.ProcessPath!,"--recovery-background"){UseShellExecute=false});Thread.Sleep(3000);}
   else if(lease.Expires<DateTimeOffset.UtcNow){/* A hung app remains owned by its process. Never spawn duplicate blockers. */}
  }catch{}Thread.Sleep(1500);}
  try{Blocker.RestoreJournal();using var key=Registry.CurrentUser.CreateSubKey(@"Software\Microsoft\Windows\CurrentVersion\Run");key.DeleteValue("LockIn Session Recovery",false);}catch{}
 }
}
