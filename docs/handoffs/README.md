# Entregas entre agentes

Crear un archivo por tarea y agente, por ejemplo `T001-codex1.md`. Mantenerlo breve:

- Tarea autorizada, agente/rol, rama y entorno de cuenta utilizado (sin credenciales).
- Identificador de trabajo/sesión del plugin cuando corresponda, para recuperar o continuar el encargo.
- Resultado y rutas afectadas.
- Comandos ejecutados y resultados observados.
- Evidencias/capturas cuando correspondan.
- Limitaciones, decisiones pendientes y siguiente acción.

En el flujo secuencial, devolver primero el resultado a Claude mediante el plugin; Claude consolida la entrega y registra commits en puntos coherentes. No exigir un commit por mensaje. En trabajo por worktrees, registrar la entrega junto con el cambio antes de integrarlo. Referenciar la rama; el hash final se obtiene con `git log`, sin intentar incrustar el hash de un commit dentro de sí mismo.
