"""Install signing assets on an ephemeral macOS runner; never print secrets."""
import base64
import datetime
import json
import os
from pathlib import Path
import plistlib
import re
import secrets
import subprocess

def command(*args):
    result = subprocess.run(args, capture_output=True)
    if result.returncode:
        raise SystemExit(f'Signing preparation failed: {args[0]}; sensitive output suppressed.')
    return result.stdout

required = ['IOS_DISTRIBUTION_P12_BASE64','IOS_P12_PASSWORD','IOS_PROFILE_BASE64',
            'ASC_KEY_ID','ASC_ISSUER_ID','ASC_PRIVATE_KEY_BASE64','ZOVV_GATEWAY_TOKEN']
missing = [name for name in required if not os.environ.get(name)]
if missing:
    raise SystemExit('Missing GitHub Secrets: '+', '.join(missing))
temp = Path(os.environ['RUNNER_TEMP'])/'zovv-signing'
temp.mkdir(mode=0o700)
for name, secret in [('distribution.p12','IOS_DISTRIBUTION_P12_BASE64'),
                     ('profile.mobileprovision','IOS_PROFILE_BASE64'),
                     ('AuthKey.p8','ASC_PRIVATE_KEY_BASE64')]:
    target = temp/name
    target.write_bytes(base64.b64decode(os.environ[secret],validate=True))
    target.chmod(0o600)
profile = plistlib.loads(command('security','cms','-D','-i',str(temp/'profile.mobileprovision')))
if profile['ExpirationDate'] <= datetime.datetime.now(datetime.timezone.utc).replace(tzinfo=None):
    raise SystemExit('Provisioning profile has expired.')
team = profile['TeamIdentifier'][0]
entitlements = profile['Entitlements']
if (not entitlements.get('application-identifier','').endswith('.com.zovv.zovv')
        or entitlements.get('get-task-allow') or profile.get('ProvisionedDevices')
        or profile.get('ProvisionsAllDevices')):
    raise SystemExit('Use an App Store Connect distribution profile for com.zovv.zovv.')
uuid = profile['UUID']
if not re.fullmatch(r'[A-Fa-f0-9-]{36}',uuid) or not re.fullmatch(r'[A-Z0-9]{10}',team):
    raise SystemExit('Invalid profile metadata.')
profile_dir = Path.home()/'Library/MobileDevice/Provisioning Profiles'
profile_dir.mkdir(parents=True, exist_ok=True)
installed = profile_dir/f'{uuid}.mobileprovision'
installed.write_bytes((temp/'profile.mobileprovision').read_bytes())
(temp/'installed-profile-path.txt').write_text(str(installed))
keychain = temp/'signing.keychain-db'
password = secrets.token_urlsafe(32)
command('security','create-keychain','-p',password,str(keychain))
command('security','set-keychain-settings','-lut','21600',str(keychain))
command('security','unlock-keychain','-p',password,str(keychain))
command('security','import',str(temp/'distribution.p12'),'-P',os.environ['IOS_P12_PASSWORD'],
        '-A','-t','cert','-f','pkcs12','-k',str(keychain))
command('security','set-key-partition-list','-S','apple-tool:,apple:,codesign:',
        '-s','-k',password,str(keychain))
command('security','list-keychains','-d','user','-s',str(keychain),
        str(Path.home()/'Library/Keychains/login.keychain-db'))
identities = command('security','find-identity','-v','-p','codesigning',str(keychain)).decode()
if not re.search(r'\b[0-9A-F]{40}\b.*Apple Distribution',identities):
    raise SystemExit('P12 must contain a valid Apple Distribution certificate and private key.')
project = Path('ios/Runner.xcodeproj/project.pbxproj')
source = project.read_text()
needle = 'PRODUCT_BUNDLE_IDENTIFIER = com.zovv.zovv;'
if source.count(needle) != 3:
    raise SystemExit('Unexpected Runner configurations; signing patch stopped.')
source = source.replace(needle,needle+f'\n\t\t\t\tDEVELOPMENT_TEAM = {team};'
    '\n\t\t\t\tCODE_SIGN_STYLE = Manual;'
    '\n\t\t\t\tCODE_SIGN_IDENTITY = "Apple Distribution";'
    f'\n\t\t\t\tPROVISIONING_PROFILE_SPECIFIER = "{uuid}";')
project.write_text(source)
(temp/'ExportOptions.plist').write_bytes(plistlib.dumps({
    'method':'app-store-connect','destination':'export','teamID':team,
    'signingStyle':'manual','signingCertificate':'Apple Distribution',
    'provisioningProfiles':{'com.zovv.zovv':uuid},'uploadSymbols':True,
    'manageAppVersionAndBuildNumber':False,'testFlightInternalTestingOnly':True,
}))
(temp/'defines.json').write_text(json.dumps({
    'ZOVV_GATEWAY':'https://140.143.201.224:8443',
    'ZOVV_GATEWAY_TOKEN':os.environ['ZOVV_GATEWAY_TOKEN'],
    'ZOVV_STREAM_PLAYBACK':'true',
}))
(temp/'defines.json').chmod(0o600)
key_dir = temp/'private_keys'
key_dir.mkdir(mode=0o700)
if not re.fullmatch(r'[A-Za-z0-9]+',os.environ['ASC_KEY_ID']):
    raise SystemExit('Invalid App Store Connect Key ID.')
key_file = key_dir/f'AuthKey_{os.environ["ASC_KEY_ID"]}.p8'
key_file.write_bytes((temp/'AuthKey.p8').read_bytes())
key_file.chmod(0o600)
with open(os.environ['GITHUB_ENV'],'a') as output:
    output.write(f'API_PRIVATE_KEYS_DIR={key_dir}\n')
print('Signing prepared for com.zovv.zovv; internal TestFlight export configured.')
