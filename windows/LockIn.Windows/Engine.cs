namespace LockIn;
public sealed class Engine {
 public static readonly string DirectoryPath=Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),"LockIn");
 public static readonly string StatePath=Path.Combine(DirectoryPath,"state.json");
 public static readonly JsonSerializerOptions Json=new(){PropertyNamingPolicy=JsonNamingPolicy.CamelCase,WriteIndented=true};
 public SavedState Data {get;private set;}=new(); public event Action? Changed; public event Action<string>? PhaseChanged;
 public Func<bool>? Authenticate; public Func<bool>? AskFutureAuthentication; public Func<string,bool>? Consent; public Func<string,bool>? Challenge;
 public Preset Setup=>Data.Presets.FirstOrDefault(p=>p.Id==Data.Selected)??Data.Custom;
 public Preset Rules=>Data.Session?.Rules??Setup;
 public bool Nuclear=>Data.Session?.Nuclear==true && Data.Session.Active(DateTimeOffset.UtcNow);
 public bool Active=>Data.Session?.Active(DateTimeOffset.UtcNow)==true;
 readonly string storage;
 public Engine(string? directory=null) {
  storage=Path.Combine(directory??DirectoryPath,"state.json");
  System.IO.Directory.CreateDirectory(directory??DirectoryPath);
  if(File.Exists(storage))try{Data=JsonSerializer.Deserialize<SavedState>(File.ReadAllText(storage),Json)??new();}catch{File.Copy(storage,storage+".recovery",true);throw new InvalidOperationException("Saved state is unreadable. A recovery copy was kept; repair state.json before restarting.");}
  Tick();
 }
 public static T Copy<T>(T value)=>JsonSerializer.Deserialize<T>(JsonSerializer.Serialize(value,Json),Json)!;
 void WriteState(){Data.Revision++;var tmp=storage+".tmp";File.WriteAllText(tmp,JsonSerializer.Serialize(Data,Json));File.Move(tmp,storage,true);}
 public void Save(){WriteState();Changed?.Invoke();}
 public void Transaction(Action action){var previous=Copy(Data);try{action();WriteState();}catch{Data=previous;throw;}Changed?.Invoke();}
 public bool VerifyNuclear() {
  if(!Data.NuclearVerified || Data.RequireAuthentication){if(Authenticate?.Invoke()!=true)return false;}
  if(!Data.NuclearVerified)Transaction(()=>{Data.NuclearVerified=true;Data.RequireAuthentication=AskFutureAuthentication?.Invoke()!=false;});return true;
 }
 public void Start() {
  if(Data.Session!=null)return;var p=Copy(Setup);if(p.Focus is <1 or >180 || p.ShortBreak is <1 or >120 || p.LongBreak is <1 or >120 || p.Cycles is <1 or >12)throw new InvalidOperationException("Check timer durations and cycles.");
  var indefinite=p.Indefinite&&p.TimerMode=="focus";var nuclear=p.Nuclear&&!indefinite;
  if(nuclear && (Consent?.Invoke("Start Nuclear Focus? No pausing or rule changes. Early ending requires a check and one of two monthly emergency exits.")!=true || !VerifyNuclear()))return;
  var now=DateTimeOffset.UtcNow;
  Transaction(()=>Data.Session=new Session{Rules=p,Nuclear=nuclear,Friction=nuclear || !indefinite&&p.ExitFriction,Started=now,Resumed=now,End=p.Indefinite&&p.TimerMode=="focus"?null:now.AddMinutes(p.Focus),Planned=p.Indefinite&&p.TimerMode=="focus"?0:p.Focus*60});
  PhaseChanged?.Invoke("focus");
 }
 public void Tick() {
  var s=Data.Session;var now=DateTimeOffset.UtcNow;if(s==null||s.PausedRemaining.HasValue||s.Waiting||s.End==null||s.End>now)return;
  Transaction(()=>{
   Record(s,true);
   if(s.Nuclear||s.Rules.TimerMode=="focus"){Data.Session=null;Data.ExitProgress=null;return;}
   if(s.Phase=="focus"){s.Cycle++;s.Phase=s.Cycle>=s.Rules.Cycles?"longBreak":"shortBreak";if(s.Phase=="longBreak")s.Cycle=0;}
   else s.Phase="focus";
   s.Planned=(s.Phase=="focus"?s.Rules.Focus:s.Phase=="longBreak"?s.Rules.LongBreak:s.Rules.ShortBreak)*60;
   s.Started=now;s.Resumed=now;s.Accumulated=0;s.End=now.AddSeconds(s.Planned);s.Waiting=!s.Rules.AutoStart;Data.ExitProgress=null;
  });PhaseChanged?.Invoke(Data.Session?.Phase??"complete");
 }
 private void Record(Session s,bool completed){if(s.Phase=="focus")Data.History.Add(new(){Date=DateTimeOffset.Now,Name=s.Rules.Name,Seconds=s.Indefinite?s.Elapsed(DateTimeOffset.UtcNow):completed?s.Planned:Math.Max(0,s.Planned-s.Remaining(DateTimeOffset.UtcNow)),Completed=completed});}
 public void StartWaiting(){if(Data.Session is not {Waiting:true} s)return;Transaction(()=>{s.Waiting=false;s.Resumed=DateTimeOffset.UtcNow;s.End=s.Resumed.AddSeconds(s.Planned);});PhaseChanged?.Invoke(s.Phase);}
 public void SkipBreak(){if(Data.Session is not {} s || s.Phase=="focus")return;Transaction(()=>{s.Phase="focus";s.Planned=s.Rules.Focus*60;s.Started=DateTimeOffset.UtcNow;s.Resumed=s.Started;s.End=s.Started.AddSeconds(s.Planned);s.Waiting=false;s.PausedRemaining=null;s.Accumulated=0;});PhaseChanged?.Invoke("focus");}
 public void AddTime(int minutes) {
  Tick();if(Data.Session is not {} s||s.Indefinite)return;var id=s.Id;var phase=s.Phase;var started=s.Started;
  if(Nuclear && Data.RequireAuthentication && Authenticate?.Invoke()!=true)return;
  Tick();if(Data.Session?.Id!=id || Data.Session.Phase!=phase || Data.Session.Started!=started)return;Transaction(()=>Policy.AddTime(Data.Session!,minutes,DateTimeOffset.UtcNow));
 }
 bool finishingChallenge;
 public void FinishChallenge(Guid sessionID,string action,DateTimeOffset? phaseStarted=null) {
  Tick();if(Data.Session?.Id!=sessionID || phaseStarted.HasValue&&Data.Session.Started!=phaseStarted.Value)return;finishingChallenge=true;try{if(action=="pause")PauseOrResume();else if(action=="stop")Stop();}finally{finishingChallenge=false;}
 }
 public void PauseOrResume() {
  Tick();if(Data.Session is not {} s || s.Waiting)return;if(Nuclear)throw new InvalidOperationException("Nuclear Mode cannot be paused.");
  var id=s.Id;
  if(!s.PausedRemaining.HasValue && s.Friction && !finishingChallenge && s.Phase=="focus" && Challenge?.Invoke("pause")!=true)return;
  Tick();if(Data.Session?.Id!=id)return;
  Transaction(()=>{var now=DateTimeOffset.UtcNow;if(s.PausedRemaining.HasValue){s.End=s.Indefinite?null:now.AddSeconds(s.PausedRemaining.Value);s.PausedRemaining=null;s.Resumed=now;}else{s.Accumulated=s.Elapsed(now);s.PausedRemaining=s.Indefinite?0:s.Remaining(now);s.End=null;}Data.ExitProgress=null;});
 }
 public void Stop() {
  Tick();if(Data.Session is not {} s)return;var id=s.Id;var nuclear=Nuclear;
  if(nuclear && Policy.RemainingExits(Data,DateTimeOffset.UtcNow)==0)throw new InvalidOperationException("Both emergency exits were used this month.");
  if(s.Friction && !finishingChallenge && s.Phase=="focus"&&!s.Waiting && Challenge?.Invoke("stop")!=true)return;
  Tick();if(Data.Session?.Id!=id)return;
  Transaction(()=>{if(nuclear){var month=Policy.Month(Data,DateTimeOffset.UtcNow);if(Data.QuotaMonth!=month){Data.QuotaMonth=month;Data.ExitsUsed=0;}if(Data.ExitsUsed>=2)throw new InvalidOperationException("No exits remain.");Data.ExitsUsed++;}Record(s,false);Data.Session=null;Data.ExitProgress=null;});
 }
 public object SyncState() {
  Tick();var s=Data.Session;var now=DateTimeOffset.UtcNow;var active=Active;var p=Rules;
  return new {protocolVersion=1,installationID=Data.InstallationID,revision=Data.Revision,sessionID=s?.Id.ToString(),sessionMode=s==null?"idle":s.Waiting?"waiting":s.PausedRemaining.HasValue?"paused":s.Phase,isFocusActive=active,ruleMode=p.Mode,presetName=p.Name,endDate=(active&&s!.Indefinite?now.AddSeconds(90):s?.End)?.ToUnixTimeMilliseconds(),domains=p.Domains,neverBlockDomains=Data.NeverDomains,appCount=p.Apps.Count,indefinite=s?.Indefinite??false,activityMode=p.TimerMode,canPause=s!=null&&!s.Waiting&&!Nuclear,canStop=s!=null&&(!Nuclear||Policy.RemainingExits(Data,now)>0),pauseRequiresChallenge=s?.Friction==true&&s.Phase=="focus"&&!s.PausedRemaining.HasValue,stopRequiresChallenge=s?.Friction==true&&s.Phase=="focus",nuclear=Nuclear,emergencyExitsRemaining=Policy.RemainingExits(Data,now),remainingSeconds=s?.Remaining(now)??0,elapsedSeconds=s?.Elapsed(now)??0,serverTime=now.ToUnixTimeMilliseconds(),blockAI=p.BlockAI,extraAIDomains=p.ExtraAI};
 }
}
