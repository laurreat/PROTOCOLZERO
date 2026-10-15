# Publicar en GitHub + build Windows

## Objective
Repo público `laurreat/PROTOCOLZERO` (rama `main`) con el proyecto completo + build Windows 64-bit real en `builds/windows/`, probado fuera del editor.

## Problem
Sin `.git` propio (raíz git = home, intocable), sin `export_presets.cfg`, README raíz inexistente (docs/README es stale Block A), stagings duplicados (PERSONA 1 54 MB idéntico por hash, PERSONA 5 31 MB), sin `gh`, push con auth por verificar (GCM 2.9 presente).

## Why
Pedido explícito 2026-10-15 en 5 fases. Prohíbe force-push, historial reescrito, secretos y builds inventados.

## Scope
- SÍ: migrar INVENTARIO + FUENTES_Y_LICENCIAS a docs/audio-provenance; borrar stagings tras hash; .gitignore (builds/, OS junk, reference-art sin licencia); README raíz (qué/cómo/releases/créditos CC-BY); git init local + commit + push (sin force; fail-fast sin prompt); preset Windows x86_64 + export + smoke test del exe; release solo si hay acceso.
- NO: licencia propia del juego (decisión del autor, se reporta); reescribir docs/README (histórico); tocar código/gameplay; incluir .godot/, builds/ o reference-art en git; publicar sin atribución CC-BY.

## Constraints
- Stagings: borrar solo tras hash idéntico (P1) o con originales integrados + licencia migrada (P5); copia externa previa (untracked).
- Push: `GIT_TERMINAL_PROMPT=0` (fallo rápido, nunca cuelgue); si pide auth, STOP y pedir al usuario.
- Release sin `gh` ni token: solo si push funciona Y hay vía autorizada; si no, build local + pasos pendientes.
- No afirmar release/build sin verificar.

## Tasks
- [x] T0 (inline) — Auditoría entorno: git 2.55, Godot 4.7.2, templates win x86_64 presentes, GCM 2.9, sin secretos, repo remoto vacío accesible, hash P1 idéntico.
- [ ] T1 (inline) — Migrar licencias + borrar stagings + .gitignore + README raíz.
- [ ] T2 (inline) — git init/add/commit/main/remote + push (o STOP con auth).
- [ ] T3 (inline) — preset + export + smoke test exe.
- [ ] T4 (inline) — release si hay acceso + validación final + informe 7 puntos.

## Authorized scope
Publicar + build 2026-10-15. Prohibido: force-push, secretos, builds falsos.

## Acceptance criteria
- `main` publicada con el proyecto completo (no solo README); commit verificable.
- `builds/windows/` con exe+pck probado fuera del editor.
- README con créditos CC-BY; sin secretos/caché/reference-art en git.

## Applicable checks
- `git status` limpio post-commit; `git ls-remote` main == local; import 0 errores; exe existe+tamaño+pck; smoke run exit 0.

## Progress
- Templates win x86_64 + GCM listos; remoto vacío accesible anónimo (lectura).

## Verification evidence
- Pendiente T4.

## Route declaration (ODD)
- Inline (Task sin transporte).

## Rollback boundary
- Copia externa stagings en Temp antes de borrar; git local conserva todo lo publicado.
