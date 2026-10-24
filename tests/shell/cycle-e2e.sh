#!/usr/bin/env bash
# Prueba real del ciclo del dock en KWin anidado con 3 ventanas de Dolphin.
set -u
cd /home/sunw/Projects/singlr
SINGLR_DURATION_MS=90000 tools/run-singlr.sh > ${TMPDIR:-/tmp}/singlr-cycle-sess.log 2>&1 &
until grep -q SINGLR_SESSION_FILE ${TMPDIR:-/tmp}/singlr-cycle-sess.log; do sleep 0.5; done
D=$(grep -m1 -oE "/tmp/singlr-session-[^ ]+/session.json" ${TMPDIR:-/tmp}/singlr-cycle-sess.log)
eval "$(python3 -c "import json,shlex;d=json.load(open('$D'));print(' '.join('export %s=%s;'%(k,shlex.quote(v)) for k,v in d['env'].items()))")"; unset DISPLAY
for p in /usr /etc /tmp; do dolphin --new-window "$p" >/dev/null 2>&1 & sleep 1.5; done
sleep 4
QT_FORCE_STDERR_LOGGING=1 timeout 30 qml6 -I shell/qml tests/shell/CycleProbe.qml 2>&1 | grep -E "CYCLE|rror" 
for p in $(pgrep -x singlr-shell); do tr '\0' '\n' < /proc/$p/environ | grep -q "SINGLR_SESSION_ID" && kill $p; done
wait
