"""Convert optional old assets/.env to a public-only local define file.

Does not print values, bundle .env, enable cloud, or mutate the legacy source.
Only simple KEY=value lines are supported; no interpolation or shell execution.
"""
import json
from pathlib import Path


def convert(root: Path) -> Path:
    config = {"APP_ENV": "local", "LOCAL_RESCUE": "true"}
    source = root / "assets/.env"
    if source.exists():
        for line in source.read_text().splitlines():
            key, separator, value = line.partition("=")
            key = key.strip().removeprefix("export ")
            if separator and key in {
                "API_BASE_URL", "SUPABASE_URL", "SUPABASE_ANON_KEY",
                "SUPABASE_PUBLISHABLE_KEY",
            }:
                value = value.strip().strip("\"'")
                if key.endswith("KEY") and value:
                    if not value.startswith("sb_publishable_"):
                        try:
                            import base64
                            parts = value.split(".")
                            payload = json.loads(base64.urlsafe_b64decode(parts[1] + "=" * (-len(parts[1]) % 4)))
                            if len(parts) != 3 or payload.get("role") != "anon":
                                raise ValueError()
                        except Exception:
                            raise ValueError("El archivo legacy contiene una clave que no es pública.") from None
                config[key] = value
    destination = root / "config/legacy.local.json"
    destination.parent.mkdir(exist_ok=True)
    destination.write_text(json.dumps(config, indent=2) + "\n")
    destination.chmod(0o600)
    return destination


if __name__ == "__main__":
    convert(Path(__file__).resolve().parents[1])
    print("Configuración pública preparada en config/legacy.local.json; rescate local activo.")
