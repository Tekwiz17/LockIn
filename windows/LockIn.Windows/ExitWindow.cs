using System.Security.Cryptography;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Media;
using System.Windows.Threading;
namespace LockIn;
public sealed class ExitWindow:Window {
 readonly Engine engine;readonly Guid session;readonly DateTimeOffset phaseStarted;readonly string action;readonly bool nuclear;readonly DispatcherTimer timer=new(){Interval=TimeSpan.FromMilliseconds(100)};
 readonly StackPanel panel=Theme.Stack();readonly TextBlock instructions=Theme.Text(""),stimulus=Theme.Text("",30),status=Theme.Text("");readonly TextBox input=Theme.Input("");readonly Button submit,finish;
 DateTimeOffset began=DateTimeOffset.UtcNow,trialStart;int kind,completed,failures,target,nbackSeen;double flashAt;bool seen,passed;string answer="",message="";
 static readonly string[] Names={"Flash recall","Stroop ink color","Flanker direction","Two-back memory","Mental arithmetic","Ascending order"};
 int Random(int max)=>RandomNumberGenerator.GetInt32(max);
 double Minimum=>kind==0?60:action=="pause"?20:nuclear?120:90;
 double Limit=>kind==0?double.PositiveInfinity:kind==3?12:kind==5?action=="pause"?22:18:kind==4?action=="pause"?15:nuclear?10:12:action=="pause"?8:5;
 public ExitWindow(Engine engine,Window owner,string action){this.engine=engine;this.action=action;session=engine.Data.Session!.Id;phaseStarted=engine.Data.Session.Started;nuclear=engine.Nuclear;Owner=owner;Theme.Window(this,action=="pause"?"Pause Check":nuclear?"Emergency Exit":"Stop Check",540,560);
  if(engine.Data.ExitProgress is {} previous&&previous.SessionId==session&&previous.Action==action){kind=previous.Kind;failures=previous.Failures;}else kind=Random(6);
  panel.Children.Add(Theme.Text(Title,24));panel.Children.Add(Theme.Button("Keep Focusing",Close));if(nuclear)panel.Children.Add(Theme.Text($"{Policy.RemainingExits(engine.Data,DateTimeOffset.UtcNow)} of 2 emergency exits remain this month."));panel.Children.Add(instructions);panel.Children.Add(stimulus);panel.Children.Add(status);panel.Children.Add(input);
  submit=Theme.Button("Submit",Submit);finish=Theme.Button(action=="pause"?"Pause Session":"End Session",()=>{if(!passed||(DateTimeOffset.UtcNow-began).TotalSeconds<Minimum)return;engine.FinishChallenge(session,action,phaseStarted);Close();});panel.Children.Add(submit);panel.Children.Add(finish);panel.Children.Add(Theme.Text("Focus keeps running until you pass and confirm. Closing this check continues Focus. These are attention checks, not clinical tests.",12,Theme.Muted));Content=panel;
  input.KeyDown+=(_,e)=>{if(e.Key==System.Windows.Input.Key.Enter&&submit.IsEnabled)Theme.Run(Submit);};Closed+=(_,_)=>timer.Stop();timer.Tick+=(_,_)=>Theme.Run(Update);NewTask();timer.Start();
 }
 void Persist(){engine.Transaction(()=>engine.Data.ExitProgress=new(){SessionId=session,Action=action,Kind=kind,Failures=failures});}
 void NewTask(){began=DateTimeOffset.UtcNow;completed=0;passed=false;target=kind==0?1:action=="pause"?5:nuclear?16:12;Persist();Next();}
 void Next(){trialStart=DateTimeOffset.UtcNow;input.Text="";seen=false;nbackSeen=0;flashAt=10+Random(350)/10d;instructions.Text=Names[kind];stimulus.Foreground=Theme.Ink;
  switch(kind){case 0:answer=(100+Random(900)).ToString();stimulus.Text="Watch for a three-digit number. Enter it after 60 seconds.";break;
   case 1:var colors=new[]{"red","blue","green","orange"};int ink=Random(4);answer=colors[ink];stimulus.Text=colors[Random(4)].ToUpperInvariant()+"\nType the INK color";stimulus.Foreground=new[]{Brushes.IndianRed,Brushes.CornflowerBlue,Brushes.LightGreen,Brushes.Orange}[ink];break;
   case 2:answer=Random(2)==0?"left":"right";var center=answer=="left"?"←":"→";var side=Random(2)==0?"←":"→";stimulus.Text=side+side+center+side+side+"\nType the CENTER arrow direction";break;
   case 3:var letters=new[]{"A","B","C","D","E","F"};var series=Enumerable.Range(0,7).Select(_=>letters[Random(6)]).ToArray();if(Random(2)==0)series[6]=series[4];answer=series[6]==series[4]?"yes":"no";stimulus.Text="Watch seven letters, then answer YES if the last matches two positions earlier, otherwise NO.";nback=series;break;
   case 4:var a=action=="pause"?10+Random(30):20+Random(70);var b=action=="pause"?2+Random(7):11+Random(19);var c=10+Random(40);answer=(a*b-c).ToString();stimulus.Text=$"({a} × {b}) − {c}";break;
   default:var numbers=Enumerable.Range(0,action=="pause"?4:6).Select(_=>10+Random(90)).ToArray();answer=string.Join(" ",numbers.OrderBy(x=>x));stimulus.Text=string.Join("   ",numbers)+"\nEnter ascending order, separated by spaces.";break;}
  Update();
 }
 string[] nback=Array.Empty<string>();
 bool CanAnswer(DateTimeOffset now){var elapsed=(now-trialStart).TotalSeconds;return !passed&&IsActive&&elapsed<Limit&&elapsed>=(kind==0?60:kind==3?7:1.5);}
 void Update(){if(engine.Data.Session?.Id!=session||engine.Data.Session.Started!=phaseStarted){Close();return;}var now=DateTimeOffset.UtcNow;var elapsed=(now-trialStart).TotalSeconds;
  if(!passed&&kind==0){if(IsActive&&elapsed>=flashAt&&elapsed<flashAt+1){stimulus.Text=answer;seen=true;}else stimulus.Text=elapsed<60?$"Watch carefully · {Math.Max(0,(int)Math.Ceiling(60-elapsed))} seconds":"Enter the number now.";}
  if(!passed&&kind==3&&IsActive&&elapsed<7)nbackSeen|=1<<Math.Min(6,(int)elapsed);
  if(!passed&&kind==3)stimulus.Text=elapsed<6?nback[Math.Min(5,(int)elapsed)]:(elapsed<7?nback[6]:"Did the last letter match two positions earlier? YES / NO");
  if(!passed&&elapsed>=Limit&&IsActive){Fail("Time ran out.");return;}
  submit.IsEnabled=CanAnswer(now);input.IsEnabled=!passed;finish.IsEnabled=passed&&(now-began).TotalSeconds>=Minimum;finish.Visibility=passed?Visibility.Visible:Visibility.Collapsed;
  status.Text=message+"\n"+(passed?$"Passed. Confirm in {Math.Max(0,(int)Math.Ceiling(Minimum-(now-began).TotalSeconds))} seconds.":$"Round {completed+1} of {target}"+(double.IsFinite(Limit)?$" · {Math.Max(0,(int)Math.Ceiling(Limit-elapsed))} seconds left":""));
 }
 void Submit(){if(!CanAnswer(DateTimeOffset.UtcNow))return;var normalized=string.Join(" ",input.Text.Trim().ToLowerInvariant().Split((char[]?)null,StringSplitOptions.RemoveEmptyEntries));if(normalized!=answer||kind==0&&!seen||kind==3&&nbackSeen!=127){Fail("Incorrect answer. Start again.");return;}completed++;message="";if(completed>=target){passed=true;stimulus.Text="Challenge passed";Update();}else Next();}
 void Fail(string text){failures++;message=text;if(failures>=2){var previous=kind;do kind=Random(6);while(kind==previous);failures=0;message+=" A different task was selected.";}NewTask();}
}
