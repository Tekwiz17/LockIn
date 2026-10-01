namespace LockIn;
public sealed class AppRule { public string Path {get;set;}=""; public string Name {get;set;}=""; }
public sealed class Preset {
 public Guid Id {get;set;}=Guid.NewGuid(); public string Name {get;set;}="Custom";
 public string Mode {get;set;}="block"; public string TimerMode {get;set;}="focus";
 public int Focus {get;set;}=25; public int ShortBreak {get;set;}=5; public int LongBreak {get;set;}=15; public int Cycles {get;set;}=4;
 public bool Indefinite {get;set;} public bool Nuclear {get;set;} public bool Strict {get;set;} public bool BlockAI {get;set;} public bool ExitFriction {get;set;}
 public bool AutoStart {get;set;}=true; public List<AppRule> Apps {get;set;}=new(); public List<string> Domains {get;set;}=new(); public List<string> ExtraAI {get;set;}=new();
}
public sealed class Session {
 public Guid Id {get;set;}=Guid.NewGuid(); public Preset Rules {get;set;}=new(); public string Phase {get;set;}="focus";
 public DateTimeOffset Started {get;set;}=DateTimeOffset.UtcNow; public DateTimeOffset? End {get;set;}
 public double Planned {get;set;} public double? PausedRemaining {get;set;} public bool Waiting {get;set;}
 public double Accumulated {get;set;} public DateTimeOffset Resumed {get;set;}=DateTimeOffset.UtcNow;
 public int Cycle {get;set;} public bool Nuclear {get;set;} public bool Friction {get;set;}
 public bool Indefinite=>Rules.TimerMode=="focus" && Rules.Indefinite;
 public double Remaining(DateTimeOffset now)=>Math.Max(0,PausedRemaining ?? (Waiting?Planned:End.HasValue?(End.Value-now).TotalSeconds:Planned));
 public double Elapsed(DateTimeOffset now)=>Math.Max(0,Accumulated+(PausedRemaining.HasValue || Waiting?0:(now-Resumed).TotalSeconds));
 public bool Active(DateTimeOffset now)=>Phase=="focus" && !Waiting && !PausedRemaining.HasValue && (Indefinite || End>now);
}
public sealed class History { public DateTimeOffset Date {get;set;} public string Name {get;set;}=""; public double Seconds {get;set;} public bool Completed {get;set;} }
public sealed class ExitProgress {public Guid SessionId {get;set;} public string Action {get;set;}="stop"; public int Kind {get;set;} public int Failures {get;set;}}
public sealed class SavedState {
 public string InstallationID {get;set;}=Guid.NewGuid().ToString(); public long Revision {get;set;}
 public Preset Custom {get;set;}=new(); public List<Preset> Presets {get;set;}=new(); public Guid? Selected {get;set;}
 public Session? Session {get;set;} public List<History> History {get;set;}=new(); public List<string> NeverDomains {get;set;}=new(); public List<AppRule> NeverApps {get;set;}=new();
 public bool NotifyFocus {get;set;}=true; public bool NotifyShort {get;set;}=true; public bool NotifyLong {get;set;}=true;
 public bool NuclearVerified {get;set;} public bool RequireAuthentication {get;set;}=true;
 public string QuotaZone {get;set;}=TimeZoneInfo.Local.Id; public string QuotaMonth {get;set;}=""; public int ExitsUsed {get;set;}
 public ExitProgress? ExitProgress {get;set;}
}
public static class Policy {
 public static bool Matches(string host,string domain)=>host.Equals(domain,StringComparison.OrdinalIgnoreCase)||host.EndsWith("."+domain,StringComparison.OrdinalIgnoreCase);
 public static string? Normalize(string input) {
  input=input.Trim();if(input.Length==0 || input.Any(c=>char.IsWhiteSpace(c)||c>127||c=='\\'))return null;
  if(!Uri.TryCreate(input.Contains("://")?input:"https://"+input,UriKind.Absolute,out var uri)||!(uri.Scheme=="https"||uri.Scheme=="http")||uri.UserInfo.Length>0)return null;
  var host=uri.Host.TrimEnd('.').ToLowerInvariant();
  var authority=(input.Contains("://")?input[(input.IndexOf("://",StringComparison.Ordinal)+3)..]:input).Split(new[]{'/','?','#'})[0];
  var colon=authority.LastIndexOf(':');if(colon>=0)authority=authority[..colon];authority=authority.TrimEnd('.').ToLowerInvariant();if(authority!=host)return null;
  return host.Length<=253 && host.Split('.').All(x=>x.Length is >0 and <=63 && x.All(c=>char.IsAsciiLetterOrDigit(c)||c=='-') && x[0]!='-' && x[^1]!='-')?host:null;
 }
 public static bool AllowsApp(string path,Session? session,IEnumerable<AppRule> never,DateTimeOffset now) {
  if(session?.Active(now)!=true || never.Any(a=>SamePath(a.Path,path)))return true;
  var selected=session.Rules.Apps.Any(a=>SamePath(a.Path,path));return session.Rules.Mode=="block"?!selected:selected;
 }
 public static bool SamePath(string a,string b)=>string.Equals(a,b,StringComparison.OrdinalIgnoreCase);
 public static string Month(SavedState state,DateTimeOffset now) {
  TimeZoneInfo zone;try{zone=TimeZoneInfo.FindSystemTimeZoneById(state.QuotaZone);}catch{zone=TimeZoneInfo.Local;}
  return TimeZoneInfo.ConvertTime(now,zone).ToString("yyyy-MM");
 }
 public static int RemainingExits(SavedState state,DateTimeOffset now)=>state.QuotaMonth==Month(state,now)?Math.Max(0,2-state.ExitsUsed):2;
 public static void AddTime(Session s,int minutes,DateTimeOffset now) {
  if(minutes is <1 or >180 || s.Indefinite || (!s.Waiting && !s.PausedRemaining.HasValue && s.End<=now))throw new InvalidOperationException("This timer can no longer be extended.");
  var amount=minutes*60d;s.Planned+=amount;if(s.PausedRemaining.HasValue)s.PausedRemaining+=amount;else if(s.End.HasValue)s.End=s.End.Value.AddSeconds(amount);
 }
}
