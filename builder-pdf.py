#!/usr/bin/env python3
"""Pipeline README.md -> PDF: pandoc (md->html) + mermaid SVG remoto + Chrome headless."""
import base64
import json
import pathlib
import re
import subprocess
import sys
import urllib.request

SRC = pathlib.Path("README.md")
CHROME = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"

src = SRC.read_text(encoding="utf-8")
diagrams = list(re.finditer(r"^```mermaid\n(.*?)^```", src, re.S | re.M))
print(f"{len(diagrams)} diagramas mermaid detectados")


def fetch_svg(code: str) -> bytes:
    """Intenta kroki.io (POST simple) y cae a mermaid.ink (GET base64url)."""
    try:
        req = urllib.request.Request(
            "https://kroki.io/mermaid/svg",
            data=code.encode("utf-8"),
            headers={"Content-Type": "text/plain"},
        )
        with urllib.request.urlopen(req, timeout=40) as r:
            data = r.read()
            if b"<svg" in data:
                return data
    except Exception as e:
        print(f"  kroki fallo ({e}); probando mermaid.ink")
    state = base64.urlsafe_b64encode(
        json.dumps({"code": code, "mermaid": {"theme": "default"}}).encode()
    ).decode().rstrip("=")
    with urllib.request.urlopen(f"https://mermaid.ink/svg/{state}", timeout=40) as r:
        return r.read()


# Sustituir cada fence por un marcador de párrafo simple
parts, last = [], 0
for j, m in enumerate(diagrams, 1):
    svg = fetch_svg(m.group(1))
    name = f"mermaid-{j:02d}.svg"
    pathlib.Path(name).write_bytes(svg)
    print(f"  diagrama {j}: {name} ({len(svg)} bytes)")
    parts.append(src[last : m.start()])
    parts.append(f"\nDIAGRAMMARKER{j}\n")
    last = m.end()
parts.append(src[last:])
pathlib.Path("tmp-doc.md").write_text("".join(parts), encoding="utf-8")

# pandoc: markdown -> fragmento html
html = subprocess.run(
    ["pandoc", "-f", "gfm", "-t", "html5", "--wrap=none", "tmp-doc.md"],
    capture_output=True, check=True,
).stdout.decode("utf-8")

# Marcadores -> <div class="diagram"><img .../></div>
for j in range(1, len(diagrams) + 1):
    html = re.sub(
        rf"<p>\s*DIAGRAMMARKER{j}\s*</p>",
        f'<div class="diagram"><img src="mermaid-{j:02d}.svg" alt="Diagrama {j}"></div>',
        html,
    )

CSS = """
@page { size: Letter; margin: 1in; }
* { box-sizing: border-box; }
body { font-family: "Helvetica Neue", Helvetica, Arial, sans-serif; font-size: 10.5pt;
       line-height: 1.5; color: #111; }
h1 { page-break-before: always; font-size: 20pt; color: #0f2f52;
     border-bottom: 2.5pt solid #367EDB; padding-bottom: 6pt; margin: 0 0 18pt; }
h1:first-of-type { page-break-before: avoid; }
h2 { font-size: 14pt; color: #1a1a1a; margin: 20pt 0 8pt; }
h3 { font-size: 12pt; margin: 16pt 0 6pt; }
p { margin: 0 0 8pt; }
table { border-collapse: collapse; width: 100%; margin: 10pt 0 14pt; font-size: 8.5pt; }
th { background: #eaf1fb; color: #0f2f52; text-align: left; }
th, td { border: 0.5pt solid #b9c4d4; padding: 4pt 6pt; vertical-align: top; }
tr { page-break-inside: avoid; }
pre { background: #f6f7f9; border: 0.5pt solid #d5d9e0; border-radius: 3pt;
      padding: 8pt 10pt; font-size: 8pt; line-height: 1.35; overflow: hidden;
      page-break-inside: avoid; white-space: pre-wrap; }
code { font-family: Menlo, Monaco, monospace; font-size: 8.5pt; }
p code, li code, td code { background: #f0f2f5; padding: 0 3pt; border-radius: 2pt; }
blockquote { border-left: 3pt solid #367EDB; margin: 10pt 0; padding: 2pt 0 2pt 12pt;
             color: #333; background: #f7fafd; }
ul, ol { margin: 0 0 10pt; padding-left: 18pt; }
li { margin-bottom: 4pt; }
.diagram { text-align: center; margin: 14pt 0; page-break-inside: avoid; }
.diagram img { max-width: 100%; max-height: 8.2in; width: auto; height: auto; }
hr { border: none; border-top: 0.5pt solid #ccc; margin: 14pt 0; }
"""

full = (
    "<!DOCTYPE html><html lang='es'><head><meta charset='utf-8'>"
    f"<style>{CSS}</style></head><body>{html}</body></html>"
)
pathlib.Path("tmp-doc.html").write_text(full, encoding="utf-8")

uri = pathlib.Path("tmp-doc.html").resolve().as_uri()
subprocess.run(
    [CHROME, "--headless=new", "--disable-gpu", "--no-pdf-header-footer",
     "--print-to-pdf=README.pdf", uri],
    capture_output=True, check=True,
)
print("PDF generado: README.pdf")
