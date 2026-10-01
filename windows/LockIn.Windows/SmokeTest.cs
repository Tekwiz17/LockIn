using System.Security.Cryptography;
using System.Windows;
using System.Windows.Media;
using System.Windows.Media.Imaging;
using System.Windows.Threading;
namespace LockIn;
/// Runs on a Windows desktop runner against the actual published EXE.
/// Uses isolated state and never registers recovery or the URL protocol.
public static class SmokeTest {
 public static int Run() {
  var directory=Path.Combine(Path.GetTempPath(),"LockIn-Smoke-"+Guid.NewGuid());
  Application? app=null;
  try {
   app=new Application{ShutdownMode=ShutdownMode.OnExplicitShutdown};
   app.DispatcherUnhandledException+=(_,e)=>{Console.Error.WriteLine(e.Exception);e.Handled=true;app.Shutdown(1);};
   var engine=new Engine(directory);
   var window=new MainWindow(engine);
   app.MainWindow=window;
   window.Show();
   app.Dispatcher.BeginInvoke(DispatcherPriority.ApplicationIdle,new Action(()=>{
    Blocker? blocker=null;
    try {
     var secret=RandomNumberGenerator.GetBytes(32);
     var protectedSecret=WindowsSecurity.Protect(secret,true);
     if(!secret.SequenceEqual(WindowsSecurity.Protect(protectedSecret,false)))throw new InvalidOperationException("DPAPI round trip failed.");
     if(window.Icon==null)throw new InvalidOperationException("Published icon resource is missing.");
     using(var icon=System.Drawing.Icon.ExtractAssociatedIcon(Environment.ProcessPath!)??throw new InvalidOperationException("EXE icon is missing."))
     using(var tray=new System.Windows.Forms.NotifyIcon{Icon=icon,Visible=false}) {tray.Text="LockIn smoke test";}
     engine.Start();
     engine.AddTime(5);
     if(engine.Data.Session?.Planned!=1800)throw new InvalidOperationException("Published timer did not extend.");
     // Empty Block selection permits every external app; exercise EnumWindows safely.
     blocker=new Blocker(engine,window,directory);
     blocker.Tick();
     Render(window);
     var editor=new RuleEditor(engine,window);editor.Show();Render(editor);editor.Close();
     var challenge=new ExitWindow(engine,window,"pause");challenge.Show();Render(challenge);challenge.Close();
     var popup=new TrayWindow(engine,()=>{},()=>{});popup.Show();Render(popup);popup.Close();
     engine.PauseOrResume();
     if(engine.Active)throw new InvalidOperationException("Published pause did not release Focus.");
     blocker.Tick();engine.PauseOrResume();engine.Stop();
     if(new Engine(directory).Data.Session!=null)throw new InvalidOperationException("Published stop did not persist.");
     Console.WriteLine("Published Windows EXE smoke check passed: WPF views, icon, tray initialization, Win32 enumeration, DPAPI, timers and persistence.");
     app.Shutdown(0);
    } catch(Exception e){Console.Error.WriteLine(e);app.Shutdown(1);}
    finally {blocker?.Dispose();}
   }));
   return app.Run();
  } catch(Exception e){Console.Error.WriteLine(e);return 1;}
  finally {if(Directory.Exists(directory))Directory.Delete(directory,true);}
 }
 static void Render(Window window) {
  window.UpdateLayout();
  var bitmap=new RenderTargetBitmap(Math.Max(1,(int)window.ActualWidth),Math.Max(1,(int)window.ActualHeight),96,96,PixelFormats.Pbgra32);
  bitmap.Render(window);
 }
}
