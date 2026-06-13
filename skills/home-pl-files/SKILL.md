---
name: home-pl-files
description: Use when transferring files to or from the home.pl hosting over SFTP — uploading a file/directory to the server or downloading from it. Triggers: "wyślij plik na home.pl", "pobierz plik z home.pl", "skopiuj katalog na serwer home.pl".
---

# home-pl-files

Przesyła pliki między komputerem lokalnym a serwerem home.pl przez SFTP (Posh-SSH, port 22222).

## Użycie

```powershell
$pluginRoot = if ($env:CLAUDE_PLUGIN_ROOT) { $env:CLAUDE_PLUGIN_ROOT } else { 'C:\claude\home-pl-plugin' }
Import-Module "$pluginRoot\lib\home-pl.psm1" -Force

# Wysłanie pliku na serwer
Send-HomePlFile -Local 'C:\dane\backup.zip' -Remote '/domains/twojadomena.pl/public_html/backup.zip'

# Pobranie pliku z serwera
Get-HomePlFile -Remote '/domains/twojadomena.pl/logs/access.log' -Local 'C:\dane\access.log'

# Katalog (Set-SFTPItem kopiuje rekurencyjnie)
Send-HomePlFile -Local 'C:\projekt' -Remote '/domains/twojadomena.pl/public_html'
```

Aby podejrzeć operację bez wykonania — `-DryRun`.

## Zasady
- Sprawdzaj `ExitCode` zwracanego obiektu; przy ≠ 0 pokaż `Output`.
- `-Remote` dla uploadu wskazuje katalog/ścieżkę docelową na serwerze; dla downloadu `-Local` to katalog/ścieżka lokalna.
- Brak konfiguracji → odeślij do skilla home-pl-setup.
