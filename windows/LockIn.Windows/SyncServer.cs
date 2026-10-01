using System.Net;
using System.Net.Sockets;
using System.Security.Cryptography;
using System.Windows;
namespace LockIn;
public sealed class BrowserCredential {public string Id {get;set;}=Guid.NewGuid().ToString();public string Name {get;set;}="";public string Token {get;set;}="";}
public sealed class SyncServer:IDisposable {
 readonly Engine engine;readonly Window owner;readonly TcpListener listener=new(IPAddress.Loopback,19287);readonly CancellationTokenSource cancel=new();readonly SemaphoreSlim slots=new(32);
 readonly string file=Path.Combine(Engine.DirectoryPath,"connections.dat");readonly Dictionary<string,(BrowserCredential Value,DateTimeOffset Expiry)> approvals=new();
 public List<BrowserCredential> Credentials {get;private set;}=new();public string Status {get;private set;}="Starting";public string? Code {get;private set;} DateTimeOffset codeExpires;
 static readonly string[] Names={"Chrome","Chromium","Brave","Edge","Firefox","Safari"};
 public SyncServer(Engine engine,Window owner){this.engine=engine;this.owner=owner;try{if(File.Exists(file))Credentials=JsonSerializer.Deserialize<List<BrowserCredential>>(WindowsSecurity.Protect(File.ReadAllBytes(file),false),Engine.Json)??new();listener.Start();Status="Ready · 127.0.0.1:19287";_ = Accept();}catch(Exception e){Status="Browser sync unavailable: "+e.Message;}}
 public static string Secret()=>Convert.ToHexString(RandomNumberGenerator.GetBytes(32)).ToLowerInvariant();
 void SaveCredentials(List<BrowserCredential> next){var temp=file+".tmp";File.WriteAllBytes(temp,WindowsSecurity.Protect(JsonSerializer.SerializeToUtf8Bytes(next,Engine.Json),true));File.Move(temp,file,true);Credentials=next;}
 public void NewCode(){Code=Secret()[..12];codeExpires=DateTimeOffset.UtcNow.AddMinutes(2);}
 public void Disconnect(BrowserCredential item){if(engine.Active)throw new InvalidOperationException("End Focus before removing a connection.");SaveCredentials(Credentials.Where(c=>c.Id!=item.Id).ToList());}
 public void HandleUri(string text){
  if(!Uri.TryCreate(text,UriKind.Absolute,out var uri)||uri.Scheme!="lockin")return;owner.Show();owner.Activate();
  if(uri.Host!="pair")return;var query=Query(uri.Query);var challenge=query.GetValueOrDefault("challenge","");var name=query.GetValueOrDefault("browser","");
  if(challenge.Length!=64 || !challenge.All(Uri.IsHexDigit)||!Names.Contains(name))return;
  Prune();if(approvals.ContainsKey(challenge)||approvals.Count>=8)return;
  if(MessageBox.Show(owner,$"Connect {name} to LockIn? Only approve if you just clicked Connect Automatically in that browser.","Pair browser",MessageBoxButton.YesNo)==MessageBoxResult.Yes)approvals[challenge]=(new(){Name=name,Token=Secret()},DateTimeOffset.UtcNow.AddMinutes(2));
 }
 void Prune(){foreach(var key in approvals.Where(a=>a.Value.Expiry<=DateTimeOffset.UtcNow).Select(a=>a.Key).ToArray())approvals.Remove(key);}
 static Dictionary<string,string> Query(string input){var result=new Dictionary<string,string>();foreach(var item in input.TrimStart('?').Split('&',StringSplitOptions.RemoveEmptyEntries)){var parts=item.Split('=',2);result[Uri.UnescapeDataString(parts[0])]=parts.Length==2?Uri.UnescapeDataString(parts[1]):"";}return result;}
 async Task Accept(){while(!cancel.IsCancellationRequested){try{var client=await listener.AcceptTcpClientAsync(cancel.Token);if(!slots.Wait(0)){client.Dispose();continue;}_=Serve(client);}catch(OperationCanceledException){break;}catch{if(cancel.IsCancellationRequested)break;await Task.Delay(500);}}}
 async Task Serve(TcpClient client){
  try{using(client){using var deadline=new CancellationTokenSource(TimeSpan.FromSeconds(28));var stream=client.GetStream();var all=new List<byte>();int boundary=-1,bodyLength=0;Dictionary<string,string> headers=new();string method="",target="";
   while(all.Count<=16384){var buffer=new byte[2048];var n=await stream.ReadAsync(buffer,deadline.Token);if(n==0)return;all.AddRange(buffer.Take(n));
    if(boundary<0){var text=Encoding.ASCII.GetString(all.ToArray());boundary=text.IndexOf("\r\n\r\n",StringComparison.Ordinal);if(boundary<0)continue;var lines=text[..boundary].Split("\r\n");var first=lines[0].Split(' ');if(first.Length!=3)return;method=first[0];target=first[1];foreach(var line in lines.Skip(1)){var pair=line.Split(':',2);if(pair.Length==2)headers[pair[0].ToLowerInvariant()]=pair[1].Trim();}if(headers.ContainsKey("transfer-encoding")||!int.TryParse(headers.GetValueOrDefault("content-length","0"),out bodyLength)||bodyLength is <0 or >4096)return;}
    if(all.Count>=boundary+4+bodyLength)break;
   }
   if(boundary<0||all.Count>16384)return;
   var body=Encoding.UTF8.GetString(all.Skip(boundary+4).Take(bodyLength).ToArray());
   var response=await owner.Dispatcher.InvokeAsync(()=>Handle(method,target,headers,body));
   if(method=="GET"&&target.StartsWith("/state?")&&response.Code==200){
    var query=Query(new Uri("http://127.0.0.1"+target).Query);
    if(long.TryParse(query.GetValueOrDefault("revision"),out var revision)){
     var until=DateTimeOffset.UtcNow.AddSeconds(20);
     while(DateTimeOffset.UtcNow<until){
      var unchanged=await owner.Dispatcher.InvokeAsync(()=>{engine.Tick();return engine.Data.Revision==revision&&query.GetValueOrDefault("installation")==engine.Data.InstallationID;});
      if(!unchanged)break;await Task.Delay(250,deadline.Token);
     }
     response=await owner.Dispatcher.InvokeAsync(()=>Handle(method,target,headers,body));
    }
   }
   var bytes=JsonSerializer.SerializeToUtf8Bytes(response.Body,Engine.Json);var head=Encoding.ASCII.GetBytes($"HTTP/1.1 {response.Code} OK\r\nContent-Type: application/json\r\nCache-Control: no-store\r\nX-Content-Type-Options: nosniff\r\nConnection: close\r\nContent-Length: {bytes.Length}\r\n\r\n");await stream.WriteAsync(head,deadline.Token);await stream.WriteAsync(bytes,deadline.Token);
  }}catch{}finally{slots.Release();}
 }
 (int Code,object Body) Handle(string method,string target,Dictionary<string,string> headers,string body){
  try{
   if(headers.GetValueOrDefault("host") is not ("127.0.0.1:19287" or "localhost:19287"))return(400,new{error="Invalid request"});
   if(headers.TryGetValue("origin",out var origin)&&!new[]{"chrome-extension://","moz-extension://","safari-web-extension://"}.Any(prefix=>origin.StartsWith(prefix,StringComparison.Ordinal)))return(403,new{error="Extension access only"});
   if(!target.StartsWith('/')||target.StartsWith("//"))return(400,new{error="Invalid path"});var uri=new Uri("http://127.0.0.1"+target);
   Dictionary<string,string> input=new();if(method=="POST")input=JsonSerializer.Deserialize<Dictionary<string,string>>(body)??new();
   if(method=="POST"&&uri.AbsolutePath=="/pair-link"){
    var key=input.GetValueOrDefault("challenge","");if(key.Length!=64||!key.All(Uri.IsHexDigit))return(400,new{error="Invalid challenge"});Prune();if(!approvals.Remove(key,out var entry))return(202,new{pending=true});SaveCredentials(Credentials.Append(entry.Value).ToList());return(200,new{token=entry.Value.Token});
   }
   if(method=="POST"&&uri.AbsolutePath=="/pair"){
    var name=input.GetValueOrDefault("name","");if(Code==null||codeExpires<=DateTimeOffset.UtcNow||input.GetValueOrDefault("code")!=Code||!Names.Contains(name))return(403,new{error="Create a new connection code in LockIn."});Code=null;
    if(MessageBox.Show(owner,$"Allow {name} to connect?", "Connect browser",MessageBoxButton.YesNo)!=MessageBoxResult.Yes)return(403,new{error="Cancelled"});var credential=new BrowserCredential{Name=name,Token=Secret()};SaveCredentials(Credentials.Append(credential).ToList());return(200,new{token=credential.Token});
   }
   if(!headers.TryGetValue("authorization",out var authorization)||!Credentials.Any(c=>EqualToken(authorization,"Bearer "+c.Token)))return(401,new{error="Connect this extension to LockIn again."});
   if(method=="GET"&&uri.AbsolutePath=="/state")return(200,engine.SyncState());
   if(method=="POST"&&uri.AbsolutePath=="/control"){
    engine.Tick();if(engine.Data.Session?.Id.ToString()!=input.GetValueOrDefault("sessionID"))return(409,new{error="Session changed. Refresh the popup."});
    switch(input.GetValueOrDefault("action")){case "pause":if(engine.Data.Session!.PausedRemaining==null)engine.PauseOrResume();break;case "resume":if(engine.Data.Session!.PausedRemaining!=null)engine.PauseOrResume();break;case "stop":engine.Stop();break;default:return(400,new{error="Unknown control"});}return(200,engine.SyncState());
   }
   return(400,new{error="Unknown endpoint"});
  }catch(Exception e){return(400,new{error=e.Message});}
 }
 static bool EqualToken(string a,string b){var x=Encoding.UTF8.GetBytes(a);var y=Encoding.UTF8.GetBytes(b);return x.Length==y.Length&&CryptographicOperations.FixedTimeEquals(x,y);}
 public void Dispose(){cancel.Cancel();listener.Stop();}
}
