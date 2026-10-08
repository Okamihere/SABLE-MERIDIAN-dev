#!/usr/bin/env python3
"""Regenera a secao automatica de novidades do CHANGELOG.md a partir do git log.

Uso:
    python3 tools/update_changelog.py [--max N]

O script atualiza apenas o bloco entre os marcadores
<!-- AUTO-START --> e <!-- AUTO-END --> no CHANGELOG.md,
preservando as entradas manuais acima dele. Rode após cada commit
para manter a página do repositório (README -> CHANGELOG) em dia.
"""
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CHANGELOG = ROOT / "CHANGELOG.md"
START = "<!-- AUTO-START -->"
END = "<!-- AUTO-END -->"


def git_log(max_entries: int) -> list[tuple[str, str, str]]:
    out = subprocess.run(
        ["git", "log", f"-{max_entries}", "--format=%h%x00%ad%x00%s", "--date=short"],
        cwd=ROOT,
        capture_output=True,
        text=True,
        check=True,
    )
    entries = []
    for line in out.stdout.strip().splitlines():
        parts = line.split("\0")
        if len(parts) == 3:
            entries.append((parts[0], parts[1], parts[2]))
    return entries


def render_auto(entries: list[tuple[str, str, str]]) -> str:
    lines = [START, "", "## Novidades (gerado do git log)", ""]
    lines.append("_Atualizado via `python3 tools/update_changelog.py`. Não edite este bloco manualmente._")
    lines.append("")
    for short_hash, date, subject in entries:
        lines.append(f"- `{date}` `{short_hash}` — {subject}")
    lines.append("")
    lines.append(END)
    return "\n".join(lines)


def main() -> int:
    max_entries = 20
    for arg in sys.argv[1:]:
        if arg.startswith("--max="):
            max_entries = int(arg.split("=", 1)[1])
        elif arg == "--help":
            print(__doc__)
            return 0
    if not CHANGELOG.exists():
        print(f"CHANGELOG não encontrado: {CHANGELOG}")
        return 1
    text = CHANGELOG.read_text(encoding="utf-8")
    if START not in text or END not in text:
        print("Marcadores AUTO-START/AUTO-END não encontrados no CHANGELOG.md")
        return 1
    before, _, rest = text.partition(START)
    _, _, after = rest.partition(END)
    entries = git_log(max_entries)
    new_block = render_auto(entries)
    CHANGELOG.write_text(before + new_block + after, encoding="utf-8")
    print(f"CHANGELOG atualizado com {len(entries)} commits.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
