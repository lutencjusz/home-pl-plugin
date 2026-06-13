# Plugin `home-pl`

Skille Claude Code do obsługi hostingu [home.pl](https://home.pl): komendy przez SSH, transfer plików (SFTP) i poczta (IMAP/SMTP). Uwierzytelnianie hasłem (port `22222`), hasła szyfrowane DPAPI.

## Skille
- **home-pl-setup** — konfiguracja połączenia, instalacja modułów i test (`~/.home-pl/config.json`).
- **home-pl-terminal** — wykonywanie komend przez SSH.
- **home-pl-files** — transfer plików przez SFTP.
- **home-pl-mail** — odczyt (IMAP) i wysyłka (SMTP) poczty.

## Instalacja

Instalacja jest dwuczęściowa: najpierw skille przez marketplace Claude Code, potem moduły PowerShell (robi to skill `home-pl-setup`).

```
# 1) Skille — marketplace Claude Code
/plugin marketplace add lutencjusz/home-pl-plugin
/plugin install home-pl@home-pl-plugin

# 2) Moduły PowerShell + konfiguracja — uruchom skill home-pl-setup
#    (instaluje Posh-SSH i Mailozaurr z PowerShell Gallery, tworzy ~/.home-pl/config.json)
```

Pominięcie kroku 2 to najczęstszy powód „zainstalowałem, a nie działa".

### Instalacja ręczna (development)
Sklonuj repo i ustaw zmienną `CLAUDE_PLUGIN_ROOT` na katalog pluginu (skille importują moduł przez `$env:CLAUDE_PLUGIN_ROOT\lib\home-pl.psm1`; po instalacji z marketplace Claude Code ustawia ją automatycznie). Alternatywnie sklonuj do domyślnej ścieżki fallback `C:\claude\home-pl-plugin`.

## Wymagania
- Windows z PowerShell 7 (`pwsh`).
- Moduły PowerShell Gallery: **Posh-SSH**, **Mailozaurr** (instaluje skill home-pl-setup).
- Konto home.pl z dostępem SSH (plany: Biznes, Profesjonalny, Premium, WordPress SSD Prof./Premium, dedykowany).

## Konfiguracja
Uruchom skill **home-pl-setup** — utworzy `~/.home-pl/config.json` (`%USERPROFILE%\.home-pl\config.json`, hasła szyfrowane DPAPI). Wzór pól znajdziesz w [`config.example.json`](config.example.json):
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
  "mailUser": "nazwa@twojadomena.pl",
  "mailPasswordEnc": "<DPAPI>"
}
```

## ⚠️ Bezpieczeństwo
- **Nie commituj** `config.json` ani haseł — `.gitignore` chroni je w repo, a plik konfiguracyjny żyje poza repo (`~/.home-pl`). Commitowany jest tylko `config.example.json` (placeholdery).
- Hasła szyfrowane DPAPI — odczyt tylko na koncie Windows, które je zapisało.
- Logowanie wyłącznie na porcie `22222` (port 22 nie działa w home.pl).
- Nie ujawniaj haseł ani treści wrażliwych w logach/odpowiedziach.

## Testy
```powershell
pwsh -NoProfile -Command "Invoke-Pester -Path tests/home-pl.Tests.ps1 -Output Detailed"
```
Testy są offline — sprawdzają buildery, walidację configu, round-trip DPAPI i logikę filtrów (bez łączenia z serwerem).

## Licencja
[MIT](LICENSE)
