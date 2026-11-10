#!/usr/bin/env python3
"""Pipeline v4: pandoc -> HTML; mermaid renderizado con Chrome --dump-dom;
SVG extraidos e inlineados; impresion final sin JS."""
import html as htmlmod
import pathlib
import re
import subprocess

CHROME = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"

frag = subprocess.run(
    ["pandoc", "-f", "gfm", "-t", "html5", "--wrap=none", "tmp-src.md"],
    capture_output=True, check=True,
).stdout.decode("utf-8")

pattern = re.compile(
    r'<pre[^>]*class="[^"]*mermaid[^"]*"[^>]*>\s*<code[^>]*>(.*?)</code>\s*</pre>'
    r'|<pre><code class="language-mermaid">(.*?)</code></pre>', re.S)
count = 0


def repl(m):
    global count
    count += 1
    inner = m.group(1) if m.group(1) is not None else m.group(2)
    return f'<pre class="mermaid">\n{htmlmod.unescape(inner)}\n</pre>'


frag = pattern.sub(repl, frag)
print(f"{count} bloques mermaid en el documento")

# --- Pasada 1: renderizar mermaid con Chrome y volcar el DOM ---
RENDER_CSS = "body{margin:20px;background:#fff} pre.mermaid{text-align:center}"
render_doc = (
    "<!DOCTYPE html><html><head><meta charset='utf-8'>"
    f"<style>{RENDER_CSS}</style></head><body>{frag}"
    "<script src='mermaid.min.js'></script>"
    "<script>mermaid.initialize({ startOnLoad: true, theme: 'default',"
    " flowchart: { htmlLabels: true }, sequence: { actorMargin: 40 } });</script>"
    "</body></html>"
)
pathlib.Path("tmp-render.html").write_text(render_doc, encoding="utf-8")
uri = pathlib.Path("tmp-render.html").resolve().as_uri()
dom = subprocess.run(
    [CHROME, "--headless=new", "--disable-gpu", "--virtual-time-budget=15000",
     "--dump-dom", uri],
    capture_output=True, check=True,
).stdout.decode("utf-8")

svgs = re.findall(r"<svg[\s\S]*?</svg>", dom)
print(f"{len(svgs)} SVG extraidos del DOM renderizado")

# --- Sustituir los <pre class="mermaid"> por los SVG inline ---
parts, last = [], 0
for i, m in enumerate(re.finditer(r'<pre class="mermaid">[\s\S]*?</pre>', frag)):
    parts.append(frag[last:m.start()])
    parts.append(f'<div class="diagram">{svgs[i]}</div>')
    last = m.end()
parts.append(frag[last:])
frag_svg = "".join(parts)

# --- Pasada 2: imprimir sin JS ---
CSS = """
@page { size: Letter; margin: 1in; }
* { box-sizing: border-box; }
body { font-family: "Helvetica Neue", Helvetica, Arial, sans-serif; font-size: 10.5pt;
       line-height: 1.5; color: #111; }
h1 { page-break-before: always; break-before: page; font-size: 20pt; color: #0f2f52;
     border-bottom: 2.5pt solid #367EDB; padding-bottom: 6pt; margin: 0 0 18pt; }
h1:first-of-type { page-break-before: avoid; break-before: auto; }
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
.diagram { text-align: center; margin: 14pt 0; page-break-inside: avoid; }
.diagram svg { max-width: 100%; max-height: 8in; width: auto; height: auto; }
blockquote { border-left: 3pt solid #367EDB; margin: 10pt 0; padding: 2pt 0 2pt 12pt;
             color: #333; background: #f7fafd; }
ul, ol { margin: 0 0 10pt; padding-left: 18pt; }
li { margin-bottom: 4pt; }
hr { border: none; border-top: 0.5pt solid #ccc; margin: 14pt 0; }
"""

final = (
    "<!DOCTYPE html><html lang='es'><head><meta charset='utf-8'>"
    f"<style>{CSS}</style></head><body>{frag_svg}</body></html>"
)
pathlib.Path("tmp-doc.html").write_text(final, encoding="utf-8")

uri = pathlib.Path("tmp-doc.html").resolve().as_uri()
subprocess.run(
    [CHROME, "--headless=new", "--disable-gpu", "--no-pdf-header-footer",
     "--print-to-pdf=README.pdf", uri],
    capture_output=True, check=True,
)
print("PDF generado: README.pdf")
