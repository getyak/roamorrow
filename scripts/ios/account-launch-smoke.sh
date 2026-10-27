#!/usr/bin/env bash
# Reuse an existing native build for real launch/UI inspection, without XCTest.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ARTIFACT_ROOT="${1:?Pass a registered account acceptance artifact directory}"
source "$ROOT/scripts/ios/session.sh"
ios_session_reexec_if_needed "$0" "$@"
ARTIFACT_ROOT="$(cd "$ARTIFACT_ROOT" && pwd -P)"
grep -Fxq "$ARTIFACT_ROOT" "$HOME/.local/state/dev-storage-guard/artifacts.list"
[[ -n "${IOS_SIMULATOR_ID:-}" ]]
APP="$ARTIFACT_ROOT/DerivedData/Build/Products/Debug-iphonesimulator/SoloCompass.app"
[[ -d "$APP" ]] || { echo 'Build the native app first.' >&2; exit 2; }
python3 - "$IOS_SIMULATOR_ID" "$APP" "$ARTIFACT_ROOT" <<'PY'
import json,os,subprocess,sys,time
device,app,root=sys.argv[1:]
def sim(*args,timeout=120):
 process=subprocess.Popen(['xcrun','simctl',*args],stdout=subprocess.PIPE,stderr=subprocess.PIPE,text=True)
 try:
  output,error=process.communicate(timeout=timeout)
 except subprocess.TimeoutExpired:
  process.terminate()
  try: process.communicate(timeout=10)
  except subprocess.TimeoutExpired:
   print('Retained non-responsive task-owned simctl PID:',process.pid,file=sys.stderr)
  raise
 if process.returncode: raise subprocess.CalledProcessError(process.returncode,process.args,output,error)
 return subprocess.CompletedProcess(process.args,process.returncode,output,error)
inventory=json.loads(sim('list','devices','available','-j').stdout)
info=next(d for ds in inventory['devices'].values() for d in ds if d['udid']==device)
if info['state']=='Shutdown': sim('boot',device)
sim('bootstatus',device,'-b',timeout=180)
sim('install',device,app)
os.environ['SIMCTL_CHILD_FF_CONTINUOUS_COMPANION']='1'
os.environ['SIMCTL_CHILD_FF_BACKEND_SYNC']='0'
result=sim('launch','--terminate-running-process',device,'com.solocompass.app',
 '-forceOnboarding','-SoloCompass.hasAcceptedTerms','YES','-AppleLanguages','(zh-Hans)','-AppleLocale','zh_CN')
time.sleep(4)
sim('io',device,'screenshot',root+'/email-entry-direct.png')
print(result.stdout.strip())
print('Direct launch screenshot captured; this is not an XCTest pass.')
PY
if [[ "${ACCOUNT_SMOKE_HOLD:-0}" == 1 ]]; then
    open -a Simulator --args -CurrentDeviceUDID "$IOS_SIMULATOR_ID"
    echo 'Holding the shared device for manual UI inspection. Send a newline to finish.'
    read -r -t 600 _ || true
fi
