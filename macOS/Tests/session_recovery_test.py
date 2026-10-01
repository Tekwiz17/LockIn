"""Exercise the actual general-session shell using simulated clock/process APIs."""
from pathlib import Path
import json, os, re, subprocess, tempfile, unittest
ROOT = Path(__file__).resolve().parents[1]
source = (ROOT/'MacApp/SessionRecovery.swift').read_text()
script = re.search(r'static let scriptSource = #"""\n(.*?)\n    """#', source, re.S).group(1)
script = '\n'.join(line[4:] if line.startswith('    ') else line for line in script.splitlines())+'\n'
class SessionRecoveryTests(unittest.TestCase):
 def run_case(self, alive=False, deadline='104', renew=False, cancel=False, pid='1234'):
  with tempfile.TemporaryDirectory() as tmp:
   folder=Path(tmp); app=folder/'LockIn space $(touch INJECTED).app';app.mkdir()
   plist=folder/'agent.plist';plist.write_text('test')
   end=folder/'deadline';end.write_text(deadline)
   (folder/'pid').write_text(pid);(folder/'clock').write_text('100');(folder/'running').write_text('yes' if alive else 'no')
   command=folder/'command';command.write_text('''#!/usr/bin/env python3
import os,sys,json
from pathlib import Path
root=Path(os.environ['LOCKIN_TEST_ROOT']);action=sys.argv[1]
if action=='date':print((root/'clock').read_text())
elif action=='sleep':
 t=int((root/'clock').read_text())+2;(root/'clock').write_text(str(t))
 if t==102 and os.environ['RENEW']=='1':(root/'deadline').write_text('108')
 if t==102 and os.environ['CANCEL']=='1':(root/'deadline').unlink()
elif action=='kill':sys.exit(0 if (root/'running').read_text()=='yes' else 1)
elif action=='ps':print(os.environ['APP']+'/Contents/MacOS/LockIn')
elif action=='open':
 with (root/'opens').open('a') as f:f.write(json.dumps(sys.argv[2:])+'\\n')
 (root/'running').write_text('yes');(root/'pid').write_text('5678')
''');command.chmod(0o700)
   value=script
   for name in ['date','sleep','kill','ps']:value=value.replace('/bin/'+name, f'"{command}" {name}')
   value=value.replace('/usr/bin/open',f'"{command}" open')
   path=folder/'script';path.write_text(value);subprocess.run(['/bin/sh','-n',str(path)],check=True)
   env={**os.environ,'LOCKIN_TEST_ROOT':tmp,'APP':str(app),'RENEW':str(int(renew)),'CANCEL':str(int(cancel))}
   result=subprocess.run(['/bin/sh',str(path),str(end),str(app),str(plist),str(folder/'pid')],env=env,cwd=tmp,capture_output=True,timeout=5)
   self.assertEqual(result.returncode,0,result.stderr)
   opens=[json.loads(s) for s in (folder/'opens').read_text().splitlines()] if (folder/'opens').exists() else []
   self.assertFalse(plist.exists());self.assertFalse((folder/'INJECTED').exists())
   return opens,int((folder/'clock').read_text()),str(app)
 def test_relaunch_once_and_literal_arguments(self):
  opens,clock,app=self.run_case();self.assertEqual(opens,[['-g',app,'--args','--recovery-background']]);self.assertEqual(clock,104)
 def test_running_app_not_duplicated_and_lease_renews(self):
  opens,clock,_=self.run_case(alive=True,renew=True);self.assertEqual(opens,[]);self.assertEqual(clock,108)
 def test_end_removes_lease_and_stops_watchdog(self):
  opens,clock,_=self.run_case(alive=True,cancel=True);self.assertEqual(opens,[]);self.assertEqual(clock,102)
 def test_expired_or_malformed_lease_does_not_restart(self):
  for value in ['99','bad']:self.assertEqual(self.run_case(deadline=value)[0],[])
 def test_malformed_pid_is_data_not_shell_code(self):self.assertEqual(len(self.run_case(pid='$(touch INJECTED)')[0]),1)
if __name__=='__main__':unittest.main(verbosity=2)
