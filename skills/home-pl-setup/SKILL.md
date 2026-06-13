---
name: home-pl-setup
description: Use when configuring the home.pl hosting connection or testing it — creating ~/.home-pl/config.json, installing the Posh-SSH and Mailozaurr modules, or verifying that SSH and mail work. Triggers: "skonfiguruj home.pl", "połącz z home.pl", "sprawdź połączenie z home.pl", "test home.pl".
---

# home-pl-setup

Konfiguruje połączenie z hostingiem home.pl (SSH/SFTP + poczta) i testuje je.

## Konfiguracja docelowa

Plik `~/.home-pl/config.json` (`%USERPROFILE%\.home-pl\config.json`, poza repozytorium pluginu). Hasła szyfrowane DPAPI.

| Pole | Znaczenie | Źródło / domyślne |
|------|-----------|-------------------|
| `host` | host SSH/SFTP | `serwerNNNNNN.home.pl` (panel home.pl) |
| `port` | port SSH/SFTP | `22222` |
| `user` | login SSH/FTP | `serwerNNNNNN` lub `kontoFTP@domena.pl` |
| `passwordEnc` | hasło SSH/SFTP (DPAPI) | użytkownik |
| `imapHost` | host IMAP | `imap.home.pl` |
| `imapPort` | port IMAP | `993` |
| `smtpHost` | host SMTP | `poczta.home.pl` |
| `smtpPort` | port SMTP | `465` |
| `mailUser` | adres skrzynki | `nazwa@twojadomena.pl` |
| `mailPasswordEnc` | hasło skrzynki (DPAPI) | użytkownik |

## Procedura

1. Zapytaj użytkownika o: host (lub numer serwera), login SSH, hasło SSH, oraz dane poczty (adres skrzynki + hasło). Port SSH domyślnie `22222`, IMAP `imap.home.pl:993`, SMTP `poczta.home.pl:465` — potwierdź lub pozwól zmienić.
2. Sprawdź i w razie braku zainstaluj moduły:
   ```powershell
   foreach ($m in 'Posh-SSH','Mailozaurr') {
     if (-not (Get-Module -ListAvailable -Name $m)) { Install-Module $m -Scope CurrentUser -Force }
   }
   ```
3. Zaimportuj moduł pluginu i zapisz konfigurację (hasła szyfrowane DPAPI):
   ```powershell
   $pluginRoot = if ($env:CLAUDE_PLUGIN_ROOT) { $env:CLAUDE_PLUGIN_ROOT } else { 'C:\claude\home-pl-plugin' }
   Import-Module "$pluginRoot\lib\home-pl.psm1" -Force
   $dir = Join-Path $HOME '.home-pl'
   if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Force $dir | Out-Null }
   @{
     host='serwer123456.home.pl'; port=22222; user='serwer123456'
     passwordEnc=(Protect-HomePlSecret -PlainText 'HASLO_SSH')
     imapHost='imap.home.pl'; imapPort=993; smtpHost='poczta.home.pl'; smtpPort=465
     mailUser='kontakt@domena.pl'
     mailPasswordEnc=(Protect-HomePlSecret -PlainText 'HASLO_SKRZYNKI')
   } | ConvertTo-Json | Set-Content -Path (Join-Path $dir 'config.json') -Encoding utf8
   ```
4. Test połączenia:
   ```powershell
   $cfg = Get-HomePlConfig -RequireMail
   "SSH echo:"; (Invoke-HomePlSSH -Command 'echo ok' -Config $cfg).Output
   "IMAP INBOX (1 ostatnia):"; Get-HomePlMail -Limit 1 -Config $cfg | Select-Object From,Subject,Date
   ```
5. Raportuj wynik: co działa (SSH / poczta), a co wymaga poprawy (złe hasło, brak dostępu SSH na danym planie, brak modułu).

## Uwagi
- Nigdy nie wypisuj haseł w odpowiedzi ani nie commituj `config.json`.
- DPAPI wiąże szyfrogram z kontem Windows — config odczyta tylko ten sam użytkownik na tej maszynie.
- SSH dostępne tylko na wybranych planach home.pl (Biznes, Profesjonalny, Premium, WordPress SSD Prof./Premium, dedykowany). Port 22 nie działa — wyłącznie `22222`.
