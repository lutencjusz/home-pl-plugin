---
name: home-pl-terminal
description: Use when running shell commands on the home.pl hosting over SSH — checking files, disk usage, running scripts on the server. Triggers: "wykonaj na home.pl", "uruchom komendę na serwerze home.pl", "sprawdź df -h na home.pl".
---

# home-pl-terminal

Wykonuje komendy na serwerze home.pl przez SSH (Posh-SSH, port 22222, uwierzytelnianie hasłem).

## Użycie

```powershell
$pluginRoot = if ($env:CLAUDE_PLUGIN_ROOT) { $env:CLAUDE_PLUGIN_ROOT } else { 'C:\claude\home-pl-plugin' }
Import-Module "$pluginRoot\lib\home-pl.psm1" -Force
$wynik = Invoke-HomePlSSH -Command 'ls -la ~/domains'
$wynik.Output
$wynik.ExitCode   # 0 = sukces
```

Aby tylko podejrzeć połączenie/komendę bez wykonania — `-DryRun` (zwraca opis bez hasła).

## Zasady
- **Polecenia destrukcyjne** (`rm -rf`, nadpisywanie plików, kasowanie) — najpierw pokaż użytkownikowi dokładną komendę i poproś o potwierdzenie, dopiero potem wykonaj.
- Po wykonaniu sprawdzaj `ExitCode`; przy ≠ 0 pokaż `Output` i wyjaśnij błąd.
- Limity home.pl: maks. **5 równoległych sesji SSH** z jednego IP, gwarantowany czas jednej sesji **30 min** — przy długich operacjach ostrzeż i podziel zadanie.
- Jeśli `Get-HomePlConfig` zgłosi brak konfiguracji — odeślij do skilla home-pl-setup.
