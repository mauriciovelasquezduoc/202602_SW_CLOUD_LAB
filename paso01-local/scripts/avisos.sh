#!/usr/bin/env bash
# ==================================================================
# Paso 01 — lee la "bandeja" simulada de notificaciones.
# En el paso 02 (nube real) estas notificaciones llegan por EMAIL.
# Aquí se guardan en una cola SQS suscrita al tópico SNS.
#
# Nota: SQS hace "invisible" cada mensaje por ~30 s tras leerlo;
# si acabas de leer la bandeja, espera 30 s y vuelve a intentar.
# ==================================================================
R=$(awslocal sqs receive-message \
  --queue-url "http://localhost:4566/000000000000/notificaciones-bandeja" \
  --max-number-of-messages 5 \
  --attribute-names All \
  --output json 2>/dev/null)

echo "$R" | python3 -c '
import sys, json
try:
    data = json.load(sys.stdin)
except Exception:
    data = {}
msgs = data.get("Messages", [])
if not msgs:
    print("(bandeja vacía: no hay notificaciones, o se leyeron hace menos de 30 s)")
for m in msgs:
    body = m.get("Body", "")
    # SNS entrega un sobre JSON; extraemos Subject y Message
    try:
        sobre = json.loads(body)
        asunto = sobre.get("Subject", "(sin asunto)")
        mensaje = sobre.get("Message", body)
    except Exception:
        asunto, mensaje = "(sin asunto)", body
    print("Asunto:", asunto)
    print(mensaje)
    print("---")
'
