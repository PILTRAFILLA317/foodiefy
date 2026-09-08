"""Write public compile-time config for the verified sibling local stack only."""
import argparse
import json
from pathlib import Path
import subprocess
from urllib.parse import urlparse

parser = argparse.ArgumentParser()
parser.add_argument('--android-emulator', action='store_true')
args = parser.parse_args()
root = Path(__file__).resolve().parents[1]
result = subprocess.run(['supabase', 'status', '--output', 'json'], cwd=root.parent / 'foodiefy_api', capture_output=True, text=True)
if result.returncode:
    raise SystemExit('Inicia Supabase local en foodiefy_api primero.')
status = json.loads(result.stdout)
url = urlparse(status['API_URL'])
if url.scheme != 'http' or url.hostname not in {'127.0.0.1', 'localhost', '::1'} or url.port != 54321:
    raise SystemExit('Destino local no reconocido; no se escribe configuración.')
host = '10.0.2.2' if args.android_emulator else '127.0.0.1'
config = {'APP_ENV': 'local', 'LOCAL_RESCUE': 'false', 'SUPABASE_URL': f'http://{host}:54321',
          'SUPABASE_ANON_KEY': status['ANON_KEY'], 'API_BASE_URL': f'http://{host}:8000'}
target = root / 'config/supabase.local.json'
if target.exists():
    raise SystemExit('config/supabase.local.json ya existe. Revísalo; no se sobrescribe.')
target.write_text(json.dumps(config, indent=2) + '\n')
print('Creada config/supabase.local.json; contiene solo configuración pública de loopback.')
