using System.Diagnostics;
using System.Runtime.InteropServices;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Interop;
namespace LockIn;
public sealed class WindowSnapshot {
 public long Handle {get;set;} public int Pid {get;set;} public long Started {get;set;} public string Path {get;set;}="";
 public Placement Placement {get;set;}
}
[StructLayout(LayoutKind.Sequential)]public struct Point {public int X,Y;}
[StructLayout(LayoutKind.Sequential)]public struct Rect {public int Left,Top,Right,Bottom;}
[StructLayout(LayoutKind.Sequential)]public struct Placement {public int Length,Flags,ShowCmd;public Point Min,Max;public Rect Normal;}
public sealed class Blocker:IDisposable {
 [UnmanagedFunctionPointer(CallingConvention.Winapi)]delegate bool EnumWindowCallback(IntPtr window,IntPtr param);
 [DllImport("user32.dll")]static extern bool EnumWindows(EnumWindowCallback callback,IntPtr param);
 [DllImport("user32.dll")]static extern bool IsWindowVisible(IntPtr handle);
 [DllImport("user32.dll")]static extern uint GetWindowThreadProcessId(IntPtr handle,out uint pid);
 [DllImport("user32.dll")]static extern IntPtr GetForegroundWindow();
 [DllImport("user32.dll")]static extern bool GetWindowPlacement(IntPtr handle,ref Placement placement);
 [DllImport("user32.dll")]static extern bool SetWindowPlacement(IntPtr handle,ref Placement placement);
 [DllImport("user32.dll")]static extern bool ShowWindow(IntPtr handle,int command);
 [DllImport("user32.dll")]static extern int GetWindowTextLength(IntPtr handle);
 readonly Engine engine;readonly Window owner;readonly string journal=Path.Combine(Engine.DirectoryPath,"hidden-windows.json");
 readonly List<WindowSnapshot> hidden=new();Window? shield;string? shieldPath;readonly Dictionary<string,DateTimeOffset> closeGrace=new(StringComparer.OrdinalIgnoreCase);
 public static readonly JsonSerializerOptions JournalJson=new(Engine.Json){IncludeFields=true};
 public Blocker(Engine engine,Window owner){this.engine=engine;this.owner=owner;RestoreJournal();}
 static bool SameProcess(WindowSnapshot w){try{using var p=Process.GetProcessById(w.Pid);GetWindowThreadProcessId(new IntPtr(w.Handle),out var pid);return pid==w.Pid&&p.StartTime.ToUniversalTime().Ticks==w.Started&&Policy.SamePath(p.MainModule?.FileName??"",w.Path);}catch{return false;}}
 static void Restore(WindowSnapshot w){if(!SameProcess(w))return;var place=w.Placement;place.Length=Marshal.SizeOf<Placement>();SetWindowPlacement(new IntPtr(w.Handle),ref place);ShowWindow(new IntPtr(w.Handle),place.ShowCmd is 2 or 6 or 7?7:place.ShowCmd==3?3:4);}
 public static void RestoreJournal(){var file=Path.Combine(Engine.DirectoryPath,"hidden-windows.json");if(!File.Exists(file))return;var windows=JsonSerializer.Deserialize<List<WindowSnapshot>>(File.ReadAllText(file),JournalJson)??new();foreach(var w in windows)Restore(w);File.Delete(file);}
 void Persist(){var temp=journal+".tmp";File.WriteAllText(temp,JsonSerializer.Serialize(hidden,JournalJson));File.Move(temp,journal,true);}
 static bool Protected(string path,int pid){var own=Environment.ProcessPath??"";var system=Environment.GetFolderPath(Environment.SpecialFolder.Windows);return pid==Environment.ProcessId||Policy.SamePath(path,own)||path.StartsWith(system+Path.DirectorySeparatorChar,StringComparison.OrdinalIgnoreCase);}
 public static List<AppRule> Applications(){var result=new List<AppRule>();foreach(var p in Process.GetProcesses()){try{if(p.MainWindowHandle==IntPtr.Zero)continue;var path=p.MainModule?.FileName;if(path==null||Protected(path,p.Id))continue;if(!result.Any(a=>Policy.SamePath(a.Path,path)))result.Add(new(){Path=path,Name=Path.GetFileNameWithoutExtension(path)});}catch{}finally{p.Dispose();}}return result.OrderBy(x=>x.Name).ToList();}
 public void Tick(){var now=DateTimeOffset.UtcNow;bool dirty=false;
  foreach(var w in hidden.ToArray()){if(!SameProcess(w)||Policy.AllowsApp(w.Path,engine.Data.Session,engine.Data.NeverApps,now)){Restore(w);hidden.Remove(w);dirty=true;}}
  if(dirty)Persist();if(!engine.Active){CloseShield();return;}
  string? blockedForeground=null;var foreground=GetForegroundWindow();
  EnumWindows((handle,_)=>{try{if(!IsWindowVisible(handle)||GetWindowTextLength(handle)==0)return true;GetWindowThreadProcessId(handle,out var id);using var process=Process.GetProcessById((int)id);var path=process.MainModule?.FileName;if(path==null||Protected(path,(int)id)||Policy.AllowsApp(path,engine.Data.Session,engine.Data.NeverApps,now))return true;
    if(closeGrace.TryGetValue(path,out var until)&&until>now)return true;
    if(handle==foreground)blockedForeground=path;
    if(!hidden.Any(w=>w.Handle==handle.ToInt64())){var placement=new Placement{Length=Marshal.SizeOf<Placement>()};if(!GetWindowPlacement(handle,ref placement))return true;hidden.Add(new(){Handle=handle.ToInt64(),Pid=(int)id,Started=process.StartTime.ToUniversalTime().Ticks,Path=path,Placement=placement});try{Persist();}catch{hidden.RemoveAt(hidden.Count-1);throw;}}
    ShowWindow(handle,0);
   }catch{}return true;},IntPtr.Zero);
  if(blockedForeground!=null)ShowShield(blockedForeground);if(shieldPath!=null&&Policy.AllowsApp(shieldPath,engine.Data.Session,engine.Data.NeverApps,now))CloseShield();
 }
 void ShowShield(string path){if(shield!=null&&Policy.SamePath(path,shieldPath??"")){shield.Activate();return;}CloseShield();shieldPath=path;var w=new Window{Owner=owner,Topmost=true,ShowInTaskbar=false};shield=w;Theme.Window(w,"LockIn · App blocked",520,410);var p=Theme.Stack();p.Children.Add(Theme.Text("LOCKIN",12,Theme.Purple));p.Children.Add(Theme.Text("Back to what matters",30));p.Children.Add(Theme.Text(Path.GetFileNameWithoutExtension(path)+" is blocked during Focus."));p.Children.Add(Theme.Text("Your session is still running. Open LockIn to manage it.",14,Theme.Muted));p.Children.Add(Theme.Button("Open LockIn",()=>{owner.Show();owner.Activate();CloseShield();}));if(engine.Data.Session?.Rules.Strict!=true)p.Children.Add(Theme.Button("Quit App",()=>{
   closeGrace[path]=DateTimeOffset.UtcNow.AddSeconds(30);foreach(var item in hidden.Where(x=>Policy.SamePath(x.Path,path)).ToArray()){Restore(item);hidden.Remove(item);try{using var process=Process.GetProcessById(item.Pid);process.CloseMainWindow();}catch{}}Persist();CloseShield();
  }));w.Content=p;w.Closed+=(_,_)=>{if(shield==w){shield=null;shieldPath=null;}};w.Show();}
 void CloseShield(){shield?.Close();shield=null;shieldPath=null;}
 public void Dispose(){CloseShield();foreach(var w in hidden)Restore(w);hidden.Clear();if(File.Exists(journal))File.Delete(journal);}
}
