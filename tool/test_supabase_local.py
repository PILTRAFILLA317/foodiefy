"""Run real Flutter repository tests against the sibling LOCAL Supabase only.
No credentials, headers or private payloads are printed. Synthetic users remain local.
"""
import json
import os
from pathlib import Path
import subprocess
from urllib.parse import urlparse

root = Path(__file__).resolve().parents[1]
api = root.parent / 'foodiefy_api'
result = subprocess.run(['supabase', 'status', '--output', 'json'], cwd=api, capture_output=True, text=True)
if result.returncode:
    raise SystemExit('Supabase local no disponible. Ejecuta supabase start en foodiefy_api.')
status = json.loads(result.stdout)
url = status['API_URL']
parsed = urlparse(url)
if parsed.scheme != 'http' or parsed.hostname not in {'localhost', '127.0.0.1', '::1'} or parsed.port != 54321:
    raise SystemExit('Se rechaza un destino que no sea la instancia local esperada.')
print('Destino comprobado: Supabase local, loopback:54321; cuentas sintéticas.', flush=True)
env = os.environ | {'FOODIEFY_LOCAL_TEST': '1', 'FOODIEFY_LOCAL_URL': url, 'FOODIEFY_LOCAL_ANON_KEY': status['ANON_KEY']}
raise SystemExit(subprocess.run(['flutter', 'test', '--no-pub', 'test/supabase_local_test.dart'], cwd=root, env=env).returncode)
