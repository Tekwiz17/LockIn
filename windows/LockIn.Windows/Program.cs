using System.Diagnostics;
using System.IO.Pipes;
using System.Security.Principal;
using System.Windows;
using System.Windows.Threading;
using Microsoft.Win32;
using Forms=System.Windows.Forms;
namespace LockIn;
public static class Program {
 static string Identity=>WindowsIdentity.GetCurrent().User!.Value.Replace('-','_');
 [STAThread]public static void Main(string[] args){
  if(args.Contains("--smoke-test")){Environment.ExitCode=SmokeTest.Run();return;}
  if(args.Contains("--watchdog")){Recovery.Watch();return;}
  using var mutex=new Mutex(true,"Local\\LockInApp-"+Identity,out var acquired);
  if(!acquired){try{using var pipe=new NamedPipeClientStream(".","LockIn-"+Identity,PipeDirection.Out,PipeOptions.None);pipe.Connect(2500);using var writer=new StreamWriter(pipe);writer.WriteLine(args.FirstOrDefault(x=>x.StartsWith("lockin://",StringComparison.OrdinalIgnoreCase))??"open");}catch{}return;}
  var app=new Application{ShutdownMode=ShutdownMode.OnExplicitShutdown};
  app.DispatcherUnhandledException+=(_,e)=>{e.Handled=true;MessageBox.Show(e.Exception.Message,"LockIn",MessageBoxButton.OK,MessageBoxImage.Warning);};
  try{
   var engine=new Engine();var window=new MainWindow(engine);app.MainWindow=window;var server=new SyncServer(engine,window);window.Server=server;var blocker=new Blocker(engine,window);
   using var tray=new Forms.NotifyIcon{Visible=true,Text="LockIn",Icon=System.Drawing.Icon.ExtractAssociatedIcon(Environment.ProcessPath!)??System.Drawing.SystemIcons.Application};Window? popup=null;
   void Open(){popup?.Close();window.Show();window.WindowState=WindowState.Normal;window.Activate();}
   void TrayPopup(){popup?.Close();popup=new TrayWindow(engine,Open,window.AddTime);var area=SystemParameters.WorkArea;popup.Left=Math.Max(area.Left,area.Right-popup.Width-16);popup.Top=Math.Max(area.Top,area.Bottom-popup.Height-12);popup.Show();popup.Activate();}
   tray.MouseClick+=(_,e)=>app.Dispatcher.Invoke(()=>{if(e.Button==Forms.MouseButtons.Left)TrayPopup();});tray.DoubleClick+=(_,_)=>app.Dispatcher.Invoke(Open);
   var menu=new Forms.ContextMenuStrip();menu.Items.Add("Open LockIn",null,(_,_)=>app.Dispatcher.Invoke(Open));menu.Items.Add("Session controls",null,(_,_)=>app.Dispatcher.Invoke(TrayPopup));tray.ContextMenuStrip=menu;
   bool quitting=false;window.Closing+=(_,e)=>{if(!quitting){e.Cancel=true;window.Hide();}};
   window.Quit=()=>{if(engine.Data.Session!=null)return;quitting=true;Recovery.Update(engine);blocker.Dispose();server.Dispose();tray.Visible=false;app.Shutdown();};
   app.Exit+=(_,_)=>{server.Dispose();try{blocker.Dispose();}catch{}};
   engine.PhaseChanged+=phase=>{var enabled=phase=="focus"?engine.Data.NotifyFocus:phase=="shortBreak"?engine.Data.NotifyShort:phase=="longBreak"?engine.Data.NotifyLong:true;if(enabled)tray.ShowBalloonTip(5000,"LockIn",phase=="complete"?"Focus complete":phase=="focus"?"Focus started":phase=="shortBreak"?"Short break started":"Long break started",Forms.ToolTipIcon.Info);};
   using(var key=Registry.CurrentUser.CreateSubKey(@"Software\Classes\lockin")){key.SetValue("","URL:LockIn protocol");key.SetValue("URL Protocol","");using var command=key.CreateSubKey(@"shell\open\command");command.SetValue("",$"\"{Environment.ProcessPath}\" \"%1\"");}
   var heartbeat=new DispatcherTimer{Interval=TimeSpan.FromMilliseconds(300)};int ticks=0;heartbeat.Tick+=(_,_)=>Theme.Run(()=>{engine.Tick();window.RefreshClock();blocker.Tick();if(++ticks%30==0)Recovery.Update(engine);});heartbeat.Start();engine.Changed+=()=>{blocker.Tick();Recovery.Update(engine);};Recovery.Update(engine);
   var cancellation=new CancellationTokenSource();app.Exit+=(_,_)=>{cancellation.Cancel();heartbeat.Stop();};_ = Listen(app,Open,server,cancellation.Token);
   window.Loaded+=(_,_)=>{foreach(var uri in args.Where(x=>x.StartsWith("lockin://",StringComparison.OrdinalIgnoreCase)))server.HandleUri(uri);};
   if(!args.Contains("--recovery-background"))window.Show();else if(args.Any(x=>x.StartsWith("lockin://",StringComparison.OrdinalIgnoreCase)))window.Show();
   app.Run();
  }catch(Exception e){MessageBox.Show(e.Message,"LockIn could not start",MessageBoxButton.OK,MessageBoxImage.Error);}
 }
 static async Task Listen(Application app,Action open,SyncServer server,CancellationToken token){while(!token.IsCancellationRequested){try{using var pipe=new NamedPipeServerStream("LockIn-"+Identity,PipeDirection.In,1,PipeTransmissionMode.Byte,PipeOptions.Asynchronous|PipeOptions.CurrentUserOnly);await pipe.WaitForConnectionAsync(token);using var reader=new StreamReader(pipe);using var limit=CancellationTokenSource.CreateLinkedTokenSource(token);limit.CancelAfter(TimeSpan.FromSeconds(3));var buffer=new char[2048];var count=0;while(count<buffer.Length){var n=await reader.ReadAsync(buffer.AsMemory(count,1),limit.Token);if(n==0||buffer[count]=='\n')break;count++;}var command=new string(buffer,0,count).Trim();await app.Dispatcher.InvokeAsync(()=>{if(command.StartsWith("lockin://",StringComparison.OrdinalIgnoreCase))server.HandleUri(command);else open();});}catch(OperationCanceledException){if(token.IsCancellationRequested)break;}catch{await Task.Delay(300,token);}}}
}
