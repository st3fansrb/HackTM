#!/usr/bin/env python3

"""
Memory script — parsează outputurile din sesiunea curentă
și actualizează automat vault-ul Obsidian FrigoBrain.
Rulează la sfârșitul fiecărei sesiuni Claude Code.
"""

import os
import re
import json
from datetime import datetime
from pathlib import Path

# Path-uri
OUTPUTS_DIR = Path(".claude/outputs")
OBSIDIAN_PATH = Path.home() / "Documents" / "FrigoBrain"
SESSIONS_DIR = OBSIDIAN_PATH / "Sessions"
MOE_LOG = OBSIDIAN_PATH / "Models" / "MoE-log"
DENSE_LOG = OBSIDIAN_PATH / "Models" / "Dense-log"
ERRORS_DIR = OBSIDIAN_PATH / "Frigo" / "Errors"

def ensure_dirs():
    for d in [SESSIONS_DIR, MOE_LOG, DENSE_LOG, ERRORS_DIR]:
        d.mkdir(parents=True, exist_ok=True)

def get_todays_outputs():
    """Returnează outputurile generate azi."""
    if not OUTPUTS_DIR.exists():
        return []
    
    today = datetime.now().strftime("%Y%m%d")
    files = [f for f in OUTPUTS_DIR.glob("*.md") if today in f.name]
    return sorted(files)

def parse_output(filepath):
    """Parsează un fișier de output și extrage informațiile relevante."""
    content = filepath.read_text(encoding="utf-8")
    
    # Extrage metadata
    model = ""
    task = ""
    confidence = None
    risk = ""
    has_escalation = False

    for line in content.split("\n"):
        if line.startswith("**Model:**"):
            model = line.replace("**Model:**", "").strip()
        elif line.startswith("# Task:"):
            task = line.replace("# Task:", "").strip()
        elif line.startswith("CONFIDENCE:"):
            try:
                confidence = int(re.search(r"\d+", line).group())
            except:
                pass
        elif line.startswith("RISK:"):
            risk = line.replace("RISK:", "").strip()
        elif "ESCALATE" in line:
            has_escalation = True

    return {
        "model": model,
        "task": task,
        "confidence": confidence,
        "risk": risk,
        "escalated": has_escalation,
        "file": filepath.name
    }

def write_session_log(outputs):
    """Scrie log-ul sesiunii în Obsidian."""
    if not outputs:
        return

    timestamp = datetime.now().strftime("%Y-%m-%d_%H-%M")
    session_file = SESSIONS_DIR / f"session_{timestamp}.md"

    lines = [
        f"# Sesiune {timestamp}",
        f"**Taskuri executate:** {len(outputs)}",
        f"**Escaladări:** {sum(1 for o in outputs if o['escalated'])}",
        "",
        "## Taskuri",
        ""
    ]

    for output in outputs:
        status = "⚠️ ESCALAT" if output["escalated"] else "✅"
        confidence_str = f"{output['confidence']}/10" if output["confidence"] else "N/A"
        lines.append(f"### {status} {output['task']}")
        lines.append(f"- **Model:** {output['model']}")
        lines.append(f"- **Confidence:** {confidence_str}")
        if output["risk"]:
            lines.append(f"- **Risk:** {output['risk']}")
        lines.append("")

    session_file.write_text("\n".join(lines), encoding="utf-8")
    print(f"✅ Session log scris: {session_file.name}")

def write_model_logs(outputs):
    """Actualizează log-urile per model în Obsidian."""
    timestamp = datetime.now().strftime("%Y-%m-%d %H:%M")

    for output in outputs:
        model = output["model"]
        
        if "8b" in model:
            log_dir = MOE_LOG
            log_file = log_dir / "log.md"
        else:
            log_dir = DENSE_LOG
            log_file = log_dir / "log.md"

        existing = log_file.read_text(encoding="utf-8") if log_file.exists() else "# Model Log\n\n"
        
        status = "⚠️" if output["escalated"] else "✅"
        confidence_str = f"{output['confidence']}/10" if output["confidence"] else "N/A"
        
        entry = f"\n## {timestamp} — {status} {output['task']}\n"
        entry += f"- Confidence: {confidence_str}\n"
        if output["risk"]:
            entry += f"- Risk: {output['risk']}\n"
        if output["escalated"]:
            entry += f"- **Escalat la Claude Code**\n"

        log_file.write_text(existing + entry, encoding="utf-8")

    print(f"✅ Model logs actualizate")

def write_error_patterns(outputs):
    """Identifică și loghează pattern-uri de erori recurente."""
    escalated = [o for o in outputs if o["escalated"]]
    
    if not escalated:
        return

    timestamp = datetime.now().strftime("%Y-%m-%d %H:%M")
    errors_file = ERRORS_DIR / "patterns.md"
    existing = errors_file.read_text(encoding="utf-8") if errors_file.exists() else "# Error Patterns\n\n"

    entry = f"\n## {timestamp}\n"
    for o in escalated:
        entry += f"- **Task:** {o['task']}\n"
        entry += f"  - Model: {o['model']}\n"
        entry += f"  - Risk: {o['risk']}\n"

    errors_file.write_text(existing + entry, encoding="utf-8")
    print(f"✅ Error patterns actualizate: {len(escalated)} escaladări")

def main():
    ensure_dirs()
    
    outputs_today = get_todays_outputs()
    
    if not outputs_today:
        print("ℹ️  Niciun output generat azi — Obsidian nu e updatat.")
        return

    print(f"📝 Procesez {len(outputs_today)} outputuri...")
    
    parsed = [parse_output(f) for f in outputs_today]
    
    write_session_log(parsed)
    write_model_logs(parsed)
    write_error_patterns(parsed)
    
    print(f"\n✅ Obsidian actualizat — {len(parsed)} taskuri logate.")

if __name__ == "__main__":
    main()