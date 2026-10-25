# Contrato: contraseñas de red dentro de Singlr

Solución técnica derivada (Claude), 24 oct. Objetivo: que nunca aparezca el diálogo de KDE y que las contraseñas se pidan en línea en el centro de control.

## C++ (Codex 2, `shell/session/**`)
- El lanzador registra un agente de secretos de NetworkManager (NetworkManagerQt `SecretAgent`) con un identificador propio, por ejemplo `org.singlr.networkmanagement`, solo cuando Singlr sustituye a Plasma.
- Lectura, guardado y borrado de secretos en KWallet con el **mismo formato y carpeta que el agente de KDE** («Network Management»), para que las redes ya guardadas sigan conectando. Si KWallet no está disponible, se devuelven los secretos que traiga la conexión.
- `tools/singlr-live.py` descarga el módulo kded `networkmanagement` al arrancar en modo de sustitución y lo vuelve a cargar al parar.
- Objeto expuesto a QML como propiedad de contexto `SinglrSecrets` (inexistente en `--windowed`):
  - señal `secretRequested(string requestId, string ssid, string connectionUuid, bool retry)`: `retry` es true si NetworkManager pide de nuevo la contraseña porque la anterior falló;
  - `Q_INVOKABLE void provide(string requestId, string password)`;
  - `Q_INVOKABLE void cancel(string requestId)`;
  - señal `requestCancelled(string requestId)`: NetworkManager canceló la petición.

## QML (Codex 1, `shell/qml/**`)
- Al recibir `secretRequested`, abre el centro de control en la página Wi-Fi con la fila de ese SSID desplegada y el campo de contraseña enfocado. Con `retry` muestra «Contraseña incorrecta». Llama a `provide` o `cancel`.
- Usa `typeof SinglrSecrets !== "undefined"` para seguir funcionando sin el lanzador.
