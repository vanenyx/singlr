#!/usr/bin/env python3
"""Comprueba configuración compartida y enlaces; no ejecuta KDE ni instala nada."""
import json
from pathlib import Path
import re
import sys
import tomllib

ROOT = Path(__file__).resolve().parents[1]
errors = []

for name in (
    "AGENTS.md", "CLAUDE.md", "README.md", "docs/status.md",
    "docs/workflow.md", "docs/decisions.md", "docs/architecture.md",
    "docs/agents/setup.md", "docs/agents/claude.md",
    "docs/agents/codex-1.md", "docs/agents/codex-2.md",
    "SINGLR_recuperacion_desde_mensajes_originales.md",
    "scripts/codex-route.sh", "scripts/codex-accounts.example",
):
    if not (ROOT / name).is_file():
        errors.append(f"Falta {name}")

for name, loader in ((".claude/settings.json", json.loads),
                     (".codex/config.toml", tomllib.loads)):
    try:
        loader((ROOT / name).read_text())
    except (OSError, ValueError) as exc:
        errors.append(f"{name}: {exc}")

skills = sorted((ROOT / ".agents/skills").glob("*/SKILL.md"))
if not skills:
    errors.append("No hay skills compartidas")
seen = set()
for manifest in skills:
    content = manifest.read_text()
    match = re.match(r"\A---\n(.*?)\n---\n", content, re.S)
    metadata = {}
    if match:
        for line in match[1].splitlines():
            key, separator, value = line.partition(":")
            if separator:
                metadata[key] = value.strip().strip('\"\'')
    name = metadata.get("name", "")
    if name != manifest.parent.name or not re.fullmatch(r"[a-z0-9-]{1,64}", name):
        errors.append(f"Nombre de skill inválido: {manifest}")
    if not metadata.get("description") or name in seen:
        errors.append(f"Descripción ausente o nombre duplicado: {manifest}")
    seen.add(name)
    link = ROOT / ".claude/skills" / manifest.parent.name
    if not link.is_symlink() or not (link / "SKILL.md").is_file():
        errors.append(f"Enlace de Claude ausente o roto: {link}")
    elif link.resolve() != manifest.parent.resolve():
        errors.append(f"Enlace de Claude apunta a otra skill: {link}")

# Enlaces Markdown relativos: detectar referencias que quedarían rotas en un clon.
for folder in (ROOT, ROOT / "docs", ROOT / ".agents/skills"):
    documents = folder.glob("*.md") if folder == ROOT else folder.rglob("*.md")
    for document in documents:
        for target in re.findall(r"\]\(([^)]+)\)", document.read_text()):
            if "://" in target or target.startswith("#"):
                continue
            target = target.split("#", 1)[0]
            if not (document.parent / target).exists():
                errors.append(f"Enlace roto en {document.relative_to(ROOT)}: {target}")

if errors:
    print("\n".join(f"ERROR: {message}" for message in errors), file=sys.stderr)
    sys.exit(1)
print(f"OK: documentos, JSON/TOML, {len(skills)} skills y enlaces compartidos.")
print("Este check no acredita carga en sesiones ni ejecución de Qt/KDE.")
