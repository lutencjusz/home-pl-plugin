# Plugin `home-pl`

[PL](README_PL.md)

[Claude Code](https://claude.com/claude-code) skills for working with [home.pl](https://home.pl)
hosting: running commands over SSH, transferring files over SFTP, and email (IMAP/SMTP).
Password authentication (port `22222`), passwords encrypted with DPAPI.

## Skills
- **home-pl-setup** — configure the connection, install modules and test (`~/.home-pl/config.json`).
- **home-pl-terminal** — run commands over SSH.
- **home-pl-files** — transfer files over SFTP.
- **home-pl-mail** — read (IMAP) and send (SMTP) email.

## Installation (two parts)

Installation has two parts: first the skills via the Claude Code marketplace, then the
PowerShell modules (handled by the `home-pl-setup` skill).

```text
# 1) Skills — Claude Code marketplace
/plugin marketplace add lutencjusz/home-pl-plugin
/plugin install home-pl@home-pl-plugin

# 2) PowerShell modules + configuration — run the home-pl-setup skill
#    (installs Posh-SSH and Mailozaurr from the PowerShell Gallery, creates ~/.home-pl/config.json)
```

Skipping step 2 is the most common reason for "I installed it but it doesn't work".

### Manual install (development)
Clone the repo and set the `CLAUDE_PLUGIN_ROOT` variable to the plugin directory (the skills
import the module via `$env:CLAUDE_PLUGIN_ROOT\lib\home-pl.psm1`; the marketplace install sets
it automatically). Alternatively, clone to the default fallback path `C:\claude\home-pl-plugin`.

## Requirements
- Windows with PowerShell 7 (`pwsh`).
- PowerShell Gallery modules: **Posh-SSH**, **Mailozaurr** (installed by the home-pl-setup skill).
- A home.pl account with SSH access (plans: Biznes, Profesjonalny, Premium, WordPress SSD Prof./Premium, dedicated).

## Configuration
Run the **home-pl-setup** skill — it creates `~/.home-pl/config.json`
(`%USERPROFILE%\.home-pl\config.json`, passwords encrypted with DPAPI). See the field template
in [`config.example.json`](config.example.json):
```json
{
  "host": "serwerNNNNNN.home.pl",
  "port": 22222,
  "user": "serwerNNNNNN",
  "passwordEnc": "<DPAPI>",
  "imapHost": "imap.home.pl",
  "imapPort": 993,
  "smtpHost": "poczta.home.pl",
  "smtpPort": 465,
  "mailUser": "name@yourdomain.pl",
  "mailPasswordEnc": "<DPAPI>"
}
```

## ⚠️ Security
- **Do not commit** `config.json` or any passwords — `.gitignore` protects them in the repo, and
  the config file lives outside the repo (`~/.home-pl`). Only `config.example.json` (placeholders)
  is committed.
- Passwords are encrypted with DPAPI — readable only by the Windows account that wrote them.
- Login only on port `22222` (port 22 does not work on home.pl).
- Never reveal passwords or sensitive content in logs/responses.

## Tests
```powershell
pwsh -NoProfile -Command "Invoke-Pester -Path tests/home-pl.Tests.ps1 -Output Detailed"
```
Tests run offline — they check the builders, config validation, DPAPI round-trip and filter logic
(without connecting to the server).

## License
[MIT](LICENSE)
