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
- [x] T1 (inline) — Licencias migradas, stagings borrados (85 MB), .gitignore, README raíz con créditos CC-BY.
- [x] T2 (inline) — git init local + 3 commits + push a main (a3d8c6c, 07d07ee, 920ddcb), local==remoto.
- [x] T3 (inline) — preset + export (exe 109 MB + pck 53 MB) + smoke boot exit 0 sin errores.
- [x] T4 (inline) — Release BLOQUEADA (sin gh ni token) + validación final + informe.

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
- `git status` limpio; `git ls-remote origin main` == local (920ddcb); 661+1 archivos en 3 commits.
- Import headless 0 errores (árbol estable tras normalización del export).
- Sonda regresión 12/12 (menú, nivel, HUD, pausa, 8 docs, SFX, autoloads).
- Export: PROTOCOL-ZERO.exe (109 MB) + .pck (53 MB); smoke `--quit-after 20` exit 0, GL real, 0 errores.
- Release NO creada: sin `gh` ni token en el entorno (bloqueo honesto, pasos abajo).

## Route declaration (ODD)
- Inline (Task sin transporte).

## Rollback boundary
- Copia externa stagings en Temp antes de borrar; git local conserva todo lo publicado.
