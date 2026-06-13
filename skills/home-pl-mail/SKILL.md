---
name: home-pl-mail
description: Use when reading or sending email through a home.pl mailbox — listing/searching messages over IMAP or sending a message over SMTP. Triggers: "wyślij maila z home.pl", "sprawdź skrzynkę home.pl", "znajdź wiadomość od X", "przeczytaj nieprzeczytane maile".
---

# home-pl-mail

Obsługuje skrzynkę home.pl: odczyt/wyszukiwanie przez IMAP (`imap.home.pl:993`) i wysyłkę przez SMTP (`poczta.home.pl:465`). Oparte na module Mailozaurr.

## Użycie

```powershell
$pluginRoot = if ($env:CLAUDE_PLUGIN_ROOT) { $env:CLAUDE_PLUGIN_ROOT } else { 'C:\claude\home-pl-plugin' }
Import-Module "$pluginRoot\lib\home-pl.psm1" -Force

# Wysłanie wiadomości (tekst)
Send-HomePlMail -To 'klient@x.pl' -Subject 'Oferta' -Body 'Treść wiadomości.'

# Wysłanie HTML z załącznikiem
Send-HomePlMail -To 'klient@x.pl' -Subject 'Faktura' -Body '<b>W załączniku faktura.</b>' -Html -Attachment 'C:\faktury\FV.pdf'

# Odczyt ostatnich 10 wiadomości
Get-HomePlMail -Limit 10 | Select-Object From,Subject,Date

# Tylko nieprzeczytane
Get-HomePlMail -Unread

# Wyszukiwanie po nadawcy i temacie (filtry łączą się przez AND)
Get-HomePlMail -From 'allegro' -Subject 'zamówienie' -Limit 20

# Inny folder niż INBOX
Get-HomePlMail -Folder 'Sent' -Limit 5
```

Aby podejrzeć operację bez wykonania — `-DryRun`.

## Zasady
- Operacje poczty wymagają pełnej konfiguracji (pola IMAP/SMTP); brak → odeślij do skilla home-pl-setup.
- Nie wypisuj pełnych treści wrażliwych wiadomości bez potrzeby — domyślnie pokazuj From/Subject/Date.
- `-From`/`-Subject` to dopasowanie częściowe, bez rozróżniania wielkości liter.
