# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

A Claude Code **plugin** (`home-pl`) that exposes home.pl hosting operations as skills: SSH commands, SFTP file transfer, and IMAP/SMTP mail. All logic is PowerShell 7 (`pwsh`); there is no application to "run" — skills are invoked by Claude on the user's behalf.

## Commands

Tests are the only build/CI step. They run fully offline (no server connection — builders, config validation, DPAPI round-trip, mail filter logic):

```powershell
pwsh -NoProfile -Command "Invoke-Pester -Path tests/home-pl.Tests.ps1 -Output Detailed"
```

To exercise the module manually, import it and use `-DryRun` (returns a plan object, never contacts the server, never includes a password):

```powershell
$pluginRoot = if ($env:CLAUDE_PLUGIN_ROOT) { $env:CLAUDE_PLUGIN_ROOT } else { 'C:\claude\home-pl-plugin' }
Import-Module "$pluginRoot\lib\home-pl.psm1" -Force
Invoke-HomePlSSH -Command 'df -h' -DryRun
```

## Architecture

**Single module, thin skills.** All reusable logic lives in `lib/home-pl.psm1`. Each `skills/*/SKILL.md` is a prose instruction file that imports the module via `$env:CLAUDE_PLUGIN_ROOT\lib\home-pl.psm1` (Claude Code sets `CLAUDE_PLUGIN_ROOT` for an installed plugin; the skills fall back to `C:\claude\home-pl-plugin` when it is unset). The plugin is registered via `.claude-plugin/plugin.json` and published through `.claude-plugin/marketplace.json`.

**Config & secrets.** Runtime config lives **outside the repo** at `~/.home-pl/config.json`. `Get-HomePlConfig` validates required fields and throws a message pointing at the `home-pl-setup` skill when something is missing; pass `-RequireMail` to also require the IMAP/SMTP fields. Passwords are stored DPAPI-encrypted (`Protect-/Unprotect-HomePlSecret`) — readable only by the same Windows user on the same machine. `Get-HomePlCredential -Scope ssh|mail` is the single place that decrypts into a `PSCredential`.

**Two credential scopes.** SSH/SFTP uses `user`/`passwordEnc`; mail uses `mailUser`/`mailPasswordEnc`. They are independent — never mix them.

**Function shape (the dominant pattern).** Public functions follow: resolve config → build a `New-HomePl*Info` plan object (host/port/user/operation, **no secrets**) → if `-DryRun`, return the plan and stop → otherwise `Assert-HomePlModule` (lazy-imports Posh-SSH or Mailozaurr, throwing a setup hint if absent), get the credential, open a session in `try`/`finally` that always tears the session down. When adding a function, keep this shape and keep the `New-*Info` builder secret-free (tests assert the plan never matches the password).

**Mail specifics (Mailozaurr 2.x).**
- SMTP via `Send-EmailMessage` uses the `-Username`/`-Password` string set with `SecureSocketOptions = 'SslOnConnect'` — **not** `-Credential` (that set routes to OAuth/Graph).
- IMAP via `Connect-IMAP` uses `-UserName`/`-Password` (ClearText set), then `Search-IMAPMailbox`; messages are wrapped, real content is in `.Message` (a MimeKit `MimeMessage`) — guard against a missing `.Message` under StrictMode.
- `Get-HomePlMail` applies `Select-HomePlMail` (case-insensitive `-From`/`-Subject` AND-filter) client-side and returns newest-first (`Sort-Object Date -Descending`).

## Conventions

- **PowerShell 7 only**, `Set-StrictMode -Version Latest` in the module — code defensively against missing properties.
- Source comments and user-facing strings are **Polish**; keep that voice when editing skills or messages.
- Non-ASCII identifiers in this repo's PowerShell files are written without Polish diacritics in code/log strings (e.g. `Wyslano`, `Zalacznik`) to stay encoding-safe; full diacritics are fine in Markdown prose.
- Tests (`tests/home-pl.Tests.ps1`, Pester) assert two invariants for every new operation: a `-DryRun` plan is returned without contacting the server, and **the serialized plan never contains the password**. Add both when you add a function.
- **Destructive/outbound actions stay human-in-the-loop**: destructive SSH commands and any mail send must be shown to the user for confirmation first.

## Security

- Never commit `config.json` or any password; never print decrypted secrets in output or logs.
- home.pl SSH/SFTP is **port 22222 only** (port 22 is closed). Limits: max 5 concurrent SSH sessions per IP, ~30 min guaranteed per session — split long jobs.
- Skills resolve the module via `$env:CLAUDE_PLUGIN_ROOT` (set by Claude Code for an installed plugin) with a `C:\claude\home-pl-plugin` fallback. For a manual/dev install, set `CLAUDE_PLUGIN_ROOT` to the repo path or clone to the fallback location.
