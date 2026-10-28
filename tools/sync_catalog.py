import json
from pathlib import Path

root = Path(__file__).resolve().parent.parent
catalog = json.loads((root / "backend" / "catalog.json").read_text(encoding="utf-8"))
out = root / "assets" / "data" / "catalog_fallback.json"
out.parent.mkdir(parents=True, exist_ok=True)
out.write_text(json.dumps(catalog, ensure_ascii=False, indent=2), encoding="utf-8")
print(f"wrote {out} ({len(catalog)} entries)")
