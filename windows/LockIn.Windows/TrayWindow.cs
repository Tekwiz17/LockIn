using System.Windows;
using System.Windows.Controls;
using System.Windows.Threading;
namespace LockIn;
public sealed class TrayWindow:Window {
 bool closing;readonly DispatcherTimer timer=new(){Interval=TimeSpan.FromSeconds(1)};
 public TrayWindow(Engine engine,Action open,Action addTime){Theme.Window(this,"LockIn",360,420);MinWidth=360;ResizeMode=ResizeMode.NoResize;WindowStyle=WindowStyle.None;ShowInTaskbar=false;Topmost=true;var p=Theme.Stack();p.Children.Add(Theme.Text("LOCKIN",12,Theme.Purple));var label=Theme.Text("",18);var clock=Theme.Text("",46);var info=Theme.Text("",13,Theme.Muted);var controls=new WrapPanel();p.Children.Add(label);p.Children.Add(clock);p.Children.Add(info);p.Children.Add(controls);p.Children.Add(Theme.Button("Open LockIn",()=>{Close();open();}));Content=p;
  void Refresh(){var s=engine.Data.Session;label.Text=s==null?"Ready to focus":s.Waiting?"Waiting":s.PausedRemaining.HasValue?"Paused":engine.Nuclear?"Nuclear Focus":s.Phase=="focus"?"Focus":"Break";clock.Text=s==null?"—":Theme.Clock(s.Indefinite?s.Elapsed(DateTimeOffset.UtcNow):s.Remaining(DateTimeOffset.UtcNow));info.Text=engine.Rules.Name+" · "+engine.Rules.Apps.Count+" apps · "+engine.Rules.Domains.Count+" sites";controls.Children.Clear();if(s!=null){if(s.Waiting)controls.Children.Add(Theme.Button("Start",engine.StartWaiting));else if(!engine.Nuclear)controls.Children.Add(Theme.Button(s.PausedRemaining.HasValue?"Resume":"Pause",engine.PauseOrResume));controls.Children.Add(Theme.Button(engine.Nuclear?"Emergency exit":"Stop",engine.Stop,!engine.Nuclear||Policy.RemainingExits(engine.Data,DateTimeOffset.UtcNow)>0));if(!s.Indefinite)controls.Children.Add(Theme.Button("Add time",()=>{Close();open();addTime();}));}}
  Refresh();timer.Tick+=(_,_)=>Refresh();timer.Start();Closing+=(_,_)=>closing=true;Closed+=(_,_)=>timer.Stop();Deactivated+=(_,_)=>{if(!closing)Dispatcher.BeginInvoke(new Action(()=>{if(!closing&&IsVisible)Close();}));};
 }
}
