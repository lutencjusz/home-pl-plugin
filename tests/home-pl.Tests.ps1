Import-Module "$PSScriptRoot/../lib/home-pl.psm1" -Force

Describe 'Modul home-pl laduje sie' {
    It 'importuje sie bez bledu' {
        Get-Module home-pl | Should -Not -BeNullOrEmpty
    }
}

Describe 'Get-HomePlConfig' {
    BeforeAll {
        $script:validCfg = @{
            host='serwer123456.home.pl'; port=22222; user='serwer123456'; passwordEnc='ENC_SSH'
            imapHost='imap.home.pl'; imapPort=993; smtpHost='poczta.home.pl'; smtpPort=465
            mailUser='kontakt@domena.pl'; mailPasswordEnc='ENC_MAIL'
        }
    }

    It 'wczytuje poprawny config z pliku' {
        $path = Join-Path $TestDrive 'config.json'
        $script:validCfg | ConvertTo-Json | Set-Content -Path $path -Encoding utf8
        $cfg = Get-HomePlConfig -Path $path
        $cfg.host | Should -Be 'serwer123456.home.pl'
        $cfg.port | Should -Be 22222
    }

    It 'rzuca blad z instrukcja home-pl-setup gdy brak pliku' {
        $path = Join-Path $TestDrive 'nieistnieje.json'
        { Get-HomePlConfig -Path $path } | Should -Throw -ExpectedMessage '*home-pl-setup*'
    }

    It 'rzuca blad gdy brakuje pola SSH' {
        $path = Join-Path $TestDrive 'incomplete-ssh.json'
        $c = $script:validCfg.Clone(); $c.Remove('passwordEnc')
        $c | ConvertTo-Json | Set-Content -Path $path -Encoding utf8
        { Get-HomePlConfig -Path $path } | Should -Throw -ExpectedMessage '*passwordEnc*'
    }

    It 'bez -RequireMail przechodzi mimo braku pol poczty' {
        $path = Join-Path $TestDrive 'no-mail.json'
        $c = $script:validCfg.Clone()
        foreach ($f in 'imapHost','imapPort','smtpHost','smtpPort','mailUser','mailPasswordEnc') { $c.Remove($f) }
        $c | ConvertTo-Json | Set-Content -Path $path -Encoding utf8
        $cfg = Get-HomePlConfig -Path $path
        $cfg.host | Should -Be 'serwer123456.home.pl'
    }

    It 'z -RequireMail rzuca blad gdy brak pol poczty' {
        $path = Join-Path $TestDrive 'no-mail2.json'
        $c = $script:validCfg.Clone(); $c.Remove('mailPasswordEnc')
        $c | ConvertTo-Json | Set-Content -Path $path -Encoding utf8
        { Get-HomePlConfig -Path $path -RequireMail } | Should -Throw -ExpectedMessage '*mailPasswordEnc*'
    }
}

Describe 'DPAPI Protect/Unprotect' {
    It 'round-trip odtwarza tekst jawny' {
        $enc = Protect-HomePlSecret -PlainText 'tajneHaslo123'
        $enc | Should -Not -Be 'tajneHaslo123'
        $secure = Unprotect-HomePlSecret -Encrypted $enc
        $bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
        try { $plain = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr) }
        finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr) }
        $plain | Should -Be 'tajneHaslo123'
    }
}

Describe 'Get-HomePlCredential' {
    BeforeAll {
        $script:cfg = [pscustomobject]@{
            host='serwer123456.home.pl'; port=22222; user='serwer123456'
            passwordEnc = (Protect-HomePlSecret -PlainText 'sshPass')
            mailUser='kontakt@domena.pl'
            mailPasswordEnc = (Protect-HomePlSecret -PlainText 'mailPass')
        }
    }

    It 'scope ssh: uzytkownik i haslo SSH' {
        $cred = Get-HomePlCredential -Config $script:cfg -Scope ssh
        $cred.UserName | Should -Be 'serwer123456'
        $cred.GetNetworkCredential().Password | Should -Be 'sshPass'
    }

    It 'scope mail: adres skrzynki i haslo poczty' {
        $cred = Get-HomePlCredential -Config $script:cfg -Scope mail
        $cred.UserName | Should -Be 'kontakt@domena.pl'
        $cred.GetNetworkCredential().Password | Should -Be 'mailPass'
    }
}

Describe 'Assert-HomePlModule' {
    It 'rzuca czytelny blad gdy modulu brak' {
        InModuleScope home-pl {
            Mock Get-Module { $null }
            { Assert-HomePlModule -Name 'Posh-SSH' } | Should -Throw -ExpectedMessage '*home-pl-setup*'
        }
    }

    It 'nie rzuca gdy modul jest dostepny' {
        InModuleScope home-pl {
            Mock Get-Module { [pscustomobject]@{ Name = 'Posh-SSH' } }
            Mock Import-Module { }
            { Assert-HomePlModule -Name 'Posh-SSH' } | Should -Not -Throw
        }
    }
}

Describe 'New-HomePlSSHInfo' {
    BeforeAll {
        $script:cfg = [pscustomobject]@{
            host='serwer123456.home.pl'; port=22222; user='serwer123456'
            passwordEnc=(Protect-HomePlSecret -PlainText 'sshPass')
        }
    }
    It 'buduje opis polaczenia z host/port/user/komenda' {
        $i = New-HomePlSSHInfo -Config $script:cfg -Command 'uptime'
        $i.Tool | Should -Be 'ssh'
        $i.Host | Should -Be 'serwer123456.home.pl'
        $i.Port | Should -Be 22222
        $i.User | Should -Be 'serwer123456'
        $i.Command | Should -Be 'uptime'
    }
    It 'opis NIE zawiera hasla' {
        $i = New-HomePlSSHInfo -Config $script:cfg -Command 'uptime'
        ($i.PSObject.Properties.Name) | Should -Not -Contain 'passwordEnc'
        ($i | ConvertTo-Json) | Should -Not -Match 'sshPass'
    }
}

Describe 'Invoke-HomePlSSH -DryRun' {
    It 'zwraca opis bez wykonania i bez hasla' {
        $cfg = [pscustomobject]@{
            host='serwer123456.home.pl'; port=22222; user='serwer123456'
            passwordEnc=(Protect-HomePlSecret -PlainText 'sshPass')
        }
        $i = Invoke-HomePlSSH -Command 'df -h' -Config $cfg -DryRun
        $i.Tool | Should -Be 'ssh'
        $i.Command | Should -Be 'df -h'
        ($i | ConvertTo-Json) | Should -Not -Match 'sshPass'
    }
}

Describe 'New-HomePlSFTPInfo' {
    BeforeAll {
        $script:cfg = [pscustomobject]@{
            host='serwer123456.home.pl'; port=22222; user='serwer123456'
            passwordEnc=(Protect-HomePlSecret -PlainText 'sshPass')
        }
    }
    It 'upload: kierunek up, lokalny i zdalny ustawione' {
        $i = New-HomePlSFTPInfo -Config $script:cfg -Direction up -Local 'C:\plik.txt' -Remote '/domains/x/file.txt'
        $i.Tool | Should -Be 'sftp'
        $i.Direction | Should -Be 'up'
        $i.Local | Should -Be 'C:\plik.txt'
        $i.Remote | Should -Be '/domains/x/file.txt'
        $i.Port | Should -Be 22222
    }
    It 'download: kierunek down' {
        $i = New-HomePlSFTPInfo -Config $script:cfg -Direction down -Local 'C:\plik.txt' -Remote '/domains/x/file.txt'
        $i.Direction | Should -Be 'down'
    }
    It 'opis NIE zawiera hasla' {
        $i = New-HomePlSFTPInfo -Config $script:cfg -Direction up -Local 'C:\a' -Remote '/b'
        ($i | ConvertTo-Json) | Should -Not -Match 'sshPass'
    }
}

Describe 'Send/Get-HomePlFile -DryRun' {
    BeforeAll {
        $script:cfg = [pscustomobject]@{
            host='serwer123456.home.pl'; port=22222; user='serwer123456'
            passwordEnc=(Protect-HomePlSecret -PlainText 'sshPass')
        }
    }
    It 'Send-HomePlFile DryRun zwraca opis up' {
        $i = Send-HomePlFile -Local 'C:\plik.txt' -Remote '/domains/x/file.txt' -Config $script:cfg -DryRun
        $i.Direction | Should -Be 'up'
    }
    It 'Get-HomePlFile DryRun zwraca opis down' {
        $i = Get-HomePlFile -Remote '/domains/x/file.txt' -Local 'C:\plik.txt' -Config $script:cfg -DryRun
        $i.Direction | Should -Be 'down'
    }
}

Describe 'Send-HomePlMail -DryRun' {
    BeforeAll {
        $script:cfg = [pscustomobject]@{
            host='serwer123456.home.pl'; port=22222; user='serwer123456'
            passwordEnc=(Protect-HomePlSecret -PlainText 'sshPass')
            imapHost='imap.home.pl'; imapPort=993; smtpHost='poczta.home.pl'; smtpPort=465
            mailUser='kontakt@domena.pl'; mailPasswordEnc=(Protect-HomePlSecret -PlainText 'mailPass')
        }
    }
    It 'zwraca opis smtp z serwerem, portem, nadawca i odbiorca' {
        $i = Send-HomePlMail -To 'jan@x.pl' -Subject 'Test' -Body 'Tresc' -Config $script:cfg -DryRun
        $i.Tool | Should -Be 'smtp'
        $i.Server | Should -Be 'poczta.home.pl'
        $i.Port | Should -Be 465
        $i.From | Should -Be 'kontakt@domena.pl'
        $i.To | Should -Be 'jan@x.pl'
        $i.Subject | Should -Be 'Test'
    }
    It 'opis NIE zawiera hasla' {
        $i = Send-HomePlMail -To 'jan@x.pl' -Subject 'T' -Body 'B' -Config $script:cfg -DryRun
        ($i | ConvertTo-Json) | Should -Not -Match 'mailPass'
    }
}

Describe 'Select-HomePlMail (filtr)' {
    BeforeAll {
        $script:msgs = @(
            [pscustomobject]@{ From='Jan Kowalski <jan@x.pl>'; Subject='Faktura 03/2026' }
            [pscustomobject]@{ From='sklep@allegro.pl';        Subject='Zamowienie wyslane' }
            [pscustomobject]@{ From='jan@inny.pl';             Subject='Spotkanie' }
        )
    }
    It 'filtruje po nadawcy (czesciowe, bez wielkosci liter)' {
        $r = Select-HomePlMail -Messages $script:msgs -From 'JAN'
        $r.Count | Should -Be 2
    }
    It 'filtruje po temacie' {
        $r = Select-HomePlMail -Messages $script:msgs -Subject 'faktura'
        $r.Count | Should -Be 1
        $r[0].From | Should -Be 'Jan Kowalski <jan@x.pl>'
    }
    It 'laczy From i Subject przez AND' {
        $r = Select-HomePlMail -Messages $script:msgs -From 'jan' -Subject 'spotkanie'
        $r.Count | Should -Be 1
        $r[0].Subject | Should -Be 'Spotkanie'
    }
    It 'bez filtrow zwraca wszystkie' {
        (Select-HomePlMail -Messages $script:msgs).Count | Should -Be 3
    }
}

Describe 'Get-HomePlMail -DryRun' {
    It 'zwraca opis imap z folderem, limitem i filtrami, bez hasla' {
        $cfg = [pscustomobject]@{
            host='serwer123456.home.pl'; port=22222; user='serwer123456'
            passwordEnc=(Protect-HomePlSecret -PlainText 'sshPass')
            imapHost='imap.home.pl'; imapPort=993; smtpHost='poczta.home.pl'; smtpPort=465
            mailUser='kontakt@domena.pl'; mailPasswordEnc=(Protect-HomePlSecret -PlainText 'mailPass')
        }
        $i = Get-HomePlMail -Folder 'INBOX' -Limit 5 -From 'jan' -Subject 'faktura' -Config $cfg -DryRun
        $i.Tool | Should -Be 'imap'
        $i.Server | Should -Be 'imap.home.pl'
        $i.Port | Should -Be 993
        $i.Folder | Should -Be 'INBOX'
        $i.Limit | Should -Be 5
        $i.From | Should -Be 'jan'
        $i.Subject | Should -Be 'faktura'
        ($i | ConvertTo-Json) | Should -Not -Match 'mailPass'
    }
}
