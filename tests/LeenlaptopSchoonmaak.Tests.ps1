Import-Module (Join-Path $PSScriptRoot '..\LeenlaptopSchoonmaak.psm1') -Force

InModuleScope LeenlaptopSchoonmaak {
    function New-TestBrowserProcess {
        param([int]$Id, [string]$Sid, [DateTime]$Created = [DateTime]::UtcNow)
        $record = New-Object Microsoft.Management.Infrastructure.CimInstance('Win32_Process')
        foreach ($pair in @{
            ProcessId = [uint32]$Id; Name = 'chrome.exe'; CreationDate = $Created; OwnerSid = $Sid
        }.GetEnumerator()) {
            $record.CimInstanceProperties.Add([Microsoft.Management.Infrastructure.CimProperty]::Create($pair.Key, $pair.Value, [Microsoft.Management.Infrastructure.CimFlags]::None))
        }
        $record
    }
    Describe 'Administratorrechten voor installatie' {
        BeforeEach {
            Mock Test-Administrator { $false }
            Mock Write-Host {}
            Mock Select-TargetUser { throw 'Accountkeuze mag nog niet beginnen' }
            Mock Invoke-LeenlaptopUtility { throw 'Installatie mag nog niet beginnen' }
        }
        It 'vraagt vooraf om UAC en geeft de exitcode van het beheervenster door' {
            Mock Start-Process { [pscustomobject]@{ ExitCode = 2 } }
            (Invoke-LeenlaptopInstaller -SourcePath $TestDrive) | Should Be 2
            Assert-MockCalled Start-Process -Times 1 -Exactly -Scope It -ParameterFilter {
                $Verb -eq 'RunAs' -and $Wait -and $PassThru -and $WindowStyle -eq 'Normal' -and $ArgumentList -match '-EncodedCommand '
            }
            Assert-MockCalled Select-TargetUser -Times 0 -Exactly -Scope It
            Assert-MockCalled Invoke-LeenlaptopUtility -Times 0 -Exactly -Scope It
        }
        It 'geeft een duidelijke fout als UAC wordt geannuleerd' {
            Mock Start-Process { throw 'The operation was canceled by the user' }
            { Invoke-LeenlaptopInstaller -SourcePath $TestDrive } | Should Throw
            Assert-MockCalled Invoke-LeenlaptopUtility -Times 0 -Exactly -Scope It
        }
        It 'voorkomt opnieuw opstarten wanneer rechten na UAC nog ontbreken' {
            Mock Start-Process { throw 'Mag niet worden aangeroepen' }
            { Invoke-LeenlaptopInstaller -SourcePath $TestDrive -Elevated } | Should Throw
            Assert-MockCalled Start-Process -Times 0 -Exactly -Scope It
        }
        It 'houdt spaties en apostrofs in het bronpad letterlijk' {
            Mock Start-Process {
                $encoded = ($ArgumentList -split ' ')[-1]
                $script:launchCommand = [Text.Encoding]::Unicode.GetString([Convert]::FromBase64String($encoded))
                [pscustomobject]@{ ExitCode = 0 }
            }
            (Invoke-LeenlaptopInstaller -SourcePath "E:\Ruben's USB\release") | Should Be 0
            $script:launchCommand.Contains("'E:\Ruben''s USB\release'") | Should Be $true
            $tokens = $null; $parseErrors = $null
            [void][System.Management.Automation.Language.Parser]::ParseInput($script:launchCommand, [ref]$tokens, [ref]$parseErrors)
            $parseErrors.Count | Should Be 0
        }
        It 'vraagt niet opnieuw om UAC wanneer al als administrator gestart' {
            Mock Test-Administrator { $true }
            Mock Start-Process { throw 'Mag niet worden aangeroepen' }
            Mock Out-Host {}
            Mock Invoke-LeenlaptopUtility { [pscustomobject]@{ ExitCode = 0; Results = @(); Status = 'Cancelled' } }
            (Invoke-LeenlaptopInstaller -SourcePath $TestDrive) | Should Be 0
            Assert-MockCalled Start-Process -Times 0 -Exactly -Scope It
            Assert-MockCalled Invoke-LeenlaptopUtility -Times 1 -Exactly -Scope It -ParameterFilter { $Action -eq 'Install' -and $Interactive -and $SourcePath -eq $TestDrive }
        }
    }

    Describe 'Interactieve accountkeuze' {
        BeforeEach {
            Mock Test-Administrator { $true }
            Mock Get-AvailableTargetUsers {
                [pscustomobject]@{ Sid = 'S-1-5-21-1-2-3-1001'; Account = 'LAPTOP\leenaccount'; ProfilePath = 'C:\Users\leenaccount' }
                [pscustomobject]@{ Sid = 'S-1-5-21-1-2-3-1002'; Account = 'LAPTOP\beheer'; ProfilePath = 'C:\Users\beheer' }
            }
            Mock Resolve-TargetUser { @{ Sid = $Sid; Account = 'LAPTOP\leenaccount'; ProfilePath = $TestDrive } }
            Mock Write-Host {}
            $script:answers = New-Object 'System.Collections.Generic.Queue[string]'
            Mock Read-Host { $script:answers.Dequeue() }
        }
        It 'weigert installatie zonder rechten voordat de accountkeuze begint' {
            Mock Test-Administrator { $false }
            { Invoke-LeenlaptopUtility -Action Install -Interactive -InstallPath $TestDrive } | Should Throw
            Assert-MockCalled Read-Host -Times 0 -Exactly -Scope It
        }
        It 'sorteert accounts en resolveert de bevestigde keuze opnieuw via SID' {
            $script:answers.Enqueue('2'); $script:answers.Enqueue('j')
            $selected = Select-TargetUser
            $selected.Sid | Should Be 'S-1-5-21-1-2-3-1001'
            Assert-MockCalled Resolve-TargetUser -Times 1 -Exactly -Scope It -ParameterFilter { $Sid -eq 'S-1-5-21-1-2-3-1001' -and -not $TargetUser }
        }
        It 'weigert lege, niet-numerieke en buiten bereik vallende invoer' {
            foreach ($answer in @('', 'beheer', '-1', '3', '9999999999999', '2', 'J')) { $script:answers.Enqueue($answer) }
            (Select-TargetUser).Sid | Should Be 'S-1-5-21-1-2-3-1001'
            Assert-MockCalled Read-Host -Times 7 -Exactly -Scope It
        }
        It 'laat opnieuw kiezen wanneer de bevestiging niet J is' {
            foreach ($answer in @('1', 'N', '2', 'J')) { $script:answers.Enqueue($answer) }
            (Select-TargetUser).Sid | Should Be 'S-1-5-21-1-2-3-1001'
            Assert-MockCalled Resolve-TargetUser -Times 1 -Exactly -Scope It
        }
        It 'annuleert vanuit de lijst zonder een account te bevestigen' {
            $script:answers.Enqueue('0')
            (Select-TargetUser) | Should Be $null
            Assert-MockCalled Resolve-TargetUser -Times 0 -Exactly -Scope It
        }
        It 'annuleert ook bij de bevestiging' {
            $script:answers.Enqueue('1'); $script:answers.Enqueue('0')
            (Select-TargetUser) | Should Be $null
        }
        It 'geeft uitleg wanneer er geen bruikbare profielen zijn' {
            Mock Get-AvailableTargetUsers {}
            { Select-TargetUser } | Should Throw
            Assert-MockCalled Read-Host -Times 0 -Exactly -Scope It
        }
        It 'annuleert voor het lezen van configuratie of uitvoeren van installatie' {
            $script:answers.Enqueue('0')
            Mock Read-UtilityConfiguration { throw 'Mag niet worden aangeroepen' }
            Mock Install-UtilityPackage { throw 'Mag niet worden aangeroepen' }
            $report = Invoke-LeenlaptopUtility -Action Install -Interactive -InstallPath $TestDrive
            $report.Status | Should Be 'Cancelled'
            $report.ExitCode | Should Be 0
            Assert-MockCalled Read-UtilityConfiguration -Times 0 -Exactly -Scope It
            Assert-MockCalled Install-UtilityPackage -Times 0 -Exactly -Scope It
        }
        It 'gebruikt de gekozen profielmap voor migratie en behoudt WhatIf' {
            $script:answers.Enqueue('2'); $script:answers.Enqueue('J')
            Mock Read-UtilityConfiguration { @{ Config = (Get-DefaultConfiguration); Source = 'test' } }
            Mock Install-UtilityPackage { throw 'Mag niet worden aangeroepen' }
            $report = Invoke-LeenlaptopUtility -Action Install -Interactive -InstallPath $TestDrive -WhatIf
            $report.Config.TargetUserSid | Should Be 'S-1-5-21-1-2-3-1001'
            Assert-MockCalled Read-UtilityConfiguration -Times 1 -Exactly -Scope It -ParameterFilter { $LegacyProfilePath -eq $TestDrive }
            Assert-MockCalled Install-UtilityPackage -Times 0 -Exactly -Scope It
        }
        It 'weigert conflicterende parameters zonder te vragen' {
            { Invoke-LeenlaptopUtility -Action Install -Interactive -TargetUser 'LAPTOP\leenaccount' -InstallPath $TestDrive } | Should Throw
            { Invoke-LeenlaptopUtility -Action Check -Interactive -InstallPath $TestDrive } | Should Throw
            Assert-MockCalled Read-Host -Times 0 -Exactly -Scope It
        }
    }

    Describe 'Beschikbare gebruikersprofielen' {
        It 'slaat systeemprofielen en niet meer beschikbare accounts over' {
            Mock Get-CimInstance {
                [pscustomobject]@{ SID = 'S-1-5-18'; Special = $true; LocalPath = 'system' }
                [pscustomobject]@{ SID = 'S-1-5-21-1-2-3-1001'; Special = $false; LocalPath = 'leenaccount' }
                [pscustomobject]@{ SID = 'S-1-5-21-1-2-3-1002'; Special = $false; LocalPath = 'deleted' }
                [pscustomobject]@{ SID = 'S-1-12-1-1-2-3-4'; Special = $false; LocalPath = 'entra' }
            }
            Mock Resolve-TargetUser {
                if ($Sid -eq 'S-1-5-21-1-2-3-1002') { throw 'Account bestaat niet meer' }
                @{ Sid = $Sid; Account = $Sid; ProfilePath = $TestDrive }
            }
            Mock Write-Warning {}
            $users = @(Get-AvailableTargetUsers)
            $users.Count | Should Be 2
            $users[1].Sid | Should Be 'S-1-12-1-1-2-3-4'
            Assert-MockCalled Resolve-TargetUser -Times 3 -Exactly -Scope It
            Assert-MockCalled Write-Warning -Times 1 -Exactly -Scope It
        }
    }

    Describe 'Configuratie en migratie' {
        It 'migreert de oude JSON-taaksleutel zonder de waarde te veranderen' {
            $path = Join-Path $TestDrive 'old-task.json'
            '{"EnableStartupTask":false}' | Set-Content $path
            $loaded = Read-UtilityConfiguration $TestDrive $TestDrive $path
            $loaded.Config.EnableScheduledTask | Should Be $false
            $loaded.Config.Contains('EnableStartupTask') | Should Be $false
        }
        It 'weigert tegenstrijdige oude en nieuwe taaksleutels' {
            $path = Join-Path $TestDrive 'conflict-task.json'
            '{"EnableStartupTask":false,"EnableScheduledTask":true}' | Set-Content $path
            { Read-UtilityConfiguration $TestDrive $TestDrive $path } | Should Throw
        }
        It 'accepteert gelijke oude en nieuwe taaksleutels' {
            $path = Join-Path $TestDrive 'same-task.json'
            '{"EnableScheduledTask":false,"EnableStartupTask":false}' | Set-Content $path
            (Read-UtilityConfiguration $TestDrive $TestDrive $path).Config.EnableScheduledTask | Should Be $false
        }
        It 'weigert automatisch aanmelden zonder geplande taak' {
            $config = Get-DefaultConfiguration
            $config.EnableScheduledTask = $false
            $config.RunAtLogon = $true
            { Test-UtilityConfiguration $config } | Should Throw
        }
        It 'migreert de oude taaksleutel uit scripts met vaste waarden' {
            $path = Join-Path $TestDrive 'old-task.ps1'
            '$EnableStartupTask = $false' | Set-Content $path
            (Import-LegacyConfiguration $path).EnableScheduledTask | Should Be $false
        }
        It 'heeft een expliciete opt-in voor automatische opschoning' {
            $config = Get-DefaultConfiguration
            $config.RunAtLogon | Should Be $false
            { Test-UtilityConfiguration $config } | Should Not Throw
        }
        It 'weigert tekst waar een boolean verwacht wordt' {
            $config = Get-DefaultConfiguration
            $config.EnableBrowserCleanup = 'false'
            { Test-UtilityConfiguration $config } | Should Throw
        }
        It 'weigert onbekende opties en ongeldige browsernamen' {
            $config = Get-DefaultConfiguration
            $config.BrowserList = @('powershell')
            { Test-UtilityConfiguration $config } | Should Throw
            $config = Get-DefaultConfiguration
            $config['Unknown'] = $true
            { Test-UtilityConfiguration $config } | Should Throw
        }
        It 'bewaart bestaande instellingen boven de distributieconfiguratie' {
            $install = Join-Path $TestDrive 'config-install'
            $source = Join-Path $TestDrive 'config-source'
            New-Item $install, $source -ItemType Directory -Force | Out-Null
            '{"DownloadsMaxAgeDays":14}' | Set-Content (Join-Path $install 'config.json')
            '{"DownloadsMaxAgeDays":2}' | Set-Content (Join-Path $source 'config.json')
            $loaded = Read-UtilityConfiguration $source $install
            $loaded.Config.DownloadsMaxAgeDays | Should Be 14
        }
        It 'migreert letterlijke instellingen zonder het oude script uit te voeren' {
            $legacy = Join-Path $TestDrive 'legacy.ps1'
            @'
[bool]$EnableDownloadsCleanup = $false
[int]$DownloadsMaxAgeDays = 42
[string[]]$AllowedWiFi = @('kantoor')
throw 'Mag nooit worden uitgevoerd'
'@ | Set-Content $legacy
            $config = Import-LegacyConfiguration $legacy
            $config.EnableDownloadsCleanup | Should Be $false
            $config.DownloadsMaxAgeDays | Should Be 42
            $config.AllowedWiFi[0] | Should Be 'kantoor'
        }
        It 'weigert dynamische oude instellingen zonder code uit te voeren' {
            $legacy = Join-Path $TestDrive 'dynamic.ps1'
            '$DownloadsMaxAgeDays = (Get-Date).Day' | Set-Content $legacy
            { Import-LegacyConfiguration $legacy } | Should Throw
        }
        It 'neemt een aangepaste oude taaknaam mee voor migratie' {
            $legacy = Join-Path $TestDrive 'custom-task.ps1'
            '$TaskName = ''OudeLeenTaak''' | Set-Content $legacy
            $taskName = ''
            $config = Import-LegacyConfiguration $legacy ([ref]$taskName)
            $taskName | Should Be 'OudeLeenTaak'
        }
        It 'houdt voorbeeldconfiguratie en ingebouwde defaults gelijk' {
            $root = Split-Path $PSScriptRoot
            $example = Get-Content (Join-Path $root 'config.example.json') -Raw | ConvertFrom-Json
            $defaults = Get-DefaultConfiguration
            foreach ($key in $defaults.Keys) {
                ($example.$key | ConvertTo-Json -Compress) | Should Be ($defaults[$key] | ConvertTo-Json -Compress)
            }
        }
    }

    Describe 'Configuratie kiezen' {
        BeforeEach {
            $caseRoot = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
            $source = Join-Path $caseRoot 'source'
            $install = Join-Path $caseRoot 'LeenlaptopSchoonmaak'
            New-Item $source, $install -ItemType Directory | Out-Null
            '{"RunAtLogon":false,"DownloadsMaxAgeDays":19}' | Set-Content (Join-Path $install 'config.json')
            '{"RunAtLogon":true,"DownloadsMaxAgeDays":3}' | Set-Content (Join-Path $source 'config.json')
            Mock Write-Host {}
        }
        It 'vindt de configuratie op beide locaties met herkenbare namen' {
            $choices = @(Get-InstallationConfigurationChoices $source $install)
            $choices.Count | Should Be 2
            $choices[0].Title | Should Be 'Bestaande installatie'
            $choices[1].Path | Should Be (Join-Path $source 'config.json')
        }
        It 'toont hetzelfde pad niet dubbel' {
            @(Get-InstallationConfigurationChoices $source $source).Count | Should Be 1
        }
        It 'gebruikt het gekozen bestand naast de installer in plaats van de bestaande configuratie' {
            Mock Read-Host { '2' }
            $loaded = Select-InstallationConfiguration $source $install
            $loaded.Config.RunAtLogon | Should Be $true
            $loaded.Config.DownloadsMaxAgeDays | Should Be 3
            $loaded.Source | Should Be (Join-Path $source 'config.json')
        }
        It 'kan ook expliciet de bestaande configuratie kiezen' {
            Mock Read-Host { '1' }
            (Select-InstallationConfiguration $source $install).Config.DownloadsMaxAgeDays | Should Be 19
        }
        It 'weigert een ongeldig gekozen bestand zonder stilzwijgend het andere te gebruiken' {
            'invalid JSON' | Set-Content (Join-Path $source 'config.json')
            Mock Read-Host { '2' }
            { Select-InstallationConfiguration $source $install } | Should Throw
        }
        It 'vraagt ook bij een enkel bestand om een keuze en weigert ongeldige invoer' {
            Remove-Item -LiteralPath (Join-Path $source 'config.json')
            $script:answers = New-Object 'System.Collections.Generic.Queue[string]'
            foreach ($answer in @('', '2', 'neen', '1')) { $script:answers.Enqueue($answer) }
            Mock Read-Host { $script:answers.Dequeue() }
            (Select-InstallationConfiguration $source $install).Config.DownloadsMaxAgeDays | Should Be 19
            Assert-MockCalled Read-Host -Times 4 -Exactly -Scope It
        }
        It 'annuleert zonder een configuratie in te lezen' {
            Mock Read-Host { '0' }
            Mock Read-UtilityConfiguration { throw 'Mag niet worden aangeroepen' }
            (Select-InstallationConfiguration $source $install) | Should Be $null
            Assert-MockCalled Read-UtilityConfiguration -Times 0 -Exactly -Scope It
        }
        It 'behoudt migratie en defaults als beide bestanden ontbreken' {
            Mock Get-InstallationConfigurationChoices {}
            Mock Read-Host { throw 'Mag niet worden aangeroepen' }
            Mock Read-UtilityConfiguration { @{ Config = (Get-DefaultConfiguration); Source = 'defaults' } }
            (Select-InstallationConfiguration $source $install 'legacy-profile').Source | Should Be 'defaults'
            Assert-MockCalled Read-UtilityConfiguration -Times 1 -Exactly -Scope It -ParameterFilter { $LegacyProfilePath -eq 'legacy-profile' -and -not $ConfigPath }
        }
    }

    Describe 'Configuratiekeuze in de installer' {
        BeforeEach {
            Mock Test-Administrator { $true }
            Mock Select-TargetUser { @{ Sid = 'S-1-5-21-1-2-3-1001'; Account = 'leenaccount'; ProfilePath = $TestDrive } }
            Mock Install-UtilityPackage { throw 'Mag niet worden aangeroepen' }
            Mock Enter-UtilityLock { throw 'Mag niet worden aangeroepen' }
        }
        It 'annuleert de installatie wanneer de configuratiekeuze wordt geannuleerd' {
            Mock Select-InstallationConfiguration { $null }
            $result = Invoke-LeenlaptopUtility -Action Install -Interactive -InstallPath $TestDrive
            $result.Status | Should Be 'Cancelled'
            $result.ExitCode | Should Be 0
            Assert-MockCalled Install-UtilityPackage -Times 0 -Exactly -Scope It
            Assert-MockCalled Enter-UtilityLock -Times 0 -Exactly -Scope It
        }
        It 'gebruikt een expliciet ConfigPath zonder configuratiekeuze' {
            Mock Select-InstallationConfiguration { throw 'Mag niet worden aangeroepen' }
            Mock Read-UtilityConfiguration { @{ Config = (Get-DefaultConfiguration); Source = $ConfigPath } }
            Mock Show-InstallationConfiguration {}
            Mock Confirm-InstallationConfiguration { $false }
            $result = Invoke-LeenlaptopUtility -Action Install -Interactive -InstallPath $TestDrive -ConfigPath 'explicit.json'
            $result.ConfigSource | Should Be 'explicit.json'
            Assert-MockCalled Select-InstallationConfiguration -Times 0 -Exactly -Scope It
        }
    }

    Describe 'Installatieoverzicht en bevestiging' {
        BeforeEach {
            Mock Write-Host {}
            Mock Test-Administrator { $true }
            Mock Select-TargetUser { @{ Sid = 'S-1-5-21-1-2-3-1001'; Account = 'LAPTOP\leenaccount'; ProfilePath = $TestDrive } }
            Mock Read-UtilityConfiguration {
                $config = Get-DefaultConfiguration
                $config.DownloadsMaxAgeDays = 19
                @{ Config = $config; Source = 'bestaande-config.json' }
            }
            Mock Install-UtilityPackage { @() }
            Mock Enter-UtilityLock { $null }
        }
        It 'toont alle instelbare opties met Nederlandse labels' {
            $config = Get-DefaultConfiguration
            $config.RunAtLogon = $true
            Show-InstallationConfiguration $config @{ Account = 'leenaccount'; ProfilePath = $TestDrive } 'defaults' $TestDrive
            Assert-MockCalled Write-Host -Times 1 -Exactly -Scope It -ParameterFilter { $Object -match '^\s+Opschonen bij aanmelden\s+: Aan$' }
            Assert-MockCalled Write-Host -Times 1 -Exactly -Scope It -ParameterFilter { $Object -match '^\s+Geplande taak\s+: Aan$' }
            Assert-MockCalled Write-Host -Times 1 -Exactly -Scope It -ParameterFilter { $Object -match '^\s+Documenten opschonen\s+: Uit \(grens: 30 dagen\)$' }
            Assert-MockCalled Write-Host -Times 1 -Exactly -Scope It -ParameterFilter { $Object -like '*Let op: na installatie*' }
        }
        It 'groepeert instellingen en koppelt bewaartermijnen aan de juiste map' {
            Show-InstallationConfiguration (Get-DefaultConfiguration) @{ Account = 'leenaccount'; ProfilePath = $TestDrive } 'defaults' $TestDrive
            Assert-MockCalled Write-Host -Times 1 -Exactly -Scope It -ParameterFilter { $Object -eq '  BESTANDEN' }
            Assert-MockCalled Write-Host -Times 1 -Exactly -Scope It -ParameterFilter { $Object -match '^\s+Downloads opschonen\s+: Aan - ouder dan 7 dagen$' }
            Assert-MockCalled Write-Host -Times 1 -Exactly -Scope It -ParameterFilter { $Object -like '*Alleen handmatig; niet automatisch*' }
        }
        It 'maakt duidelijk wanneer de bestaande configuratie voorrang heeft' {
            Show-InstallationConfiguration (Get-DefaultConfiguration) @{ Account = 'leenaccount'; ProfilePath = $TestDrive } (Join-Path $TestDrive 'config.json') $TestDrive
            Assert-MockCalled Write-Host -Times 1 -Exactly -Scope It -ParameterFilter { $Object -like '*Gekozen bron: bestaande installatie*' }
        }
        It 'toont de geladen configuratie voordat definitieve toestemming wordt gevraagd' {
            $script:overviewShown = $false
            Mock Show-InstallationConfiguration {
                if ($Config.DownloadsMaxAgeDays -ne 19 -or $ConfigSource -ne 'bestaande-config.json') { throw 'Verkeerde configuratie' }
                $script:overviewShown = $true
            }
            Mock Confirm-InstallationConfiguration {
                if (-not $script:overviewShown) { throw 'Overzicht ontbreekt' }
                $false
            }
            $report = Invoke-LeenlaptopUtility -Action Install -Interactive -InstallPath $TestDrive
            $report.Status | Should Be 'Cancelled'
            Assert-MockCalled Install-UtilityPackage -Times 0 -Exactly -Scope It
            Assert-MockCalled Enter-UtilityLock -Times 0 -Exactly -Scope It
        }
        It 'installeert pas nadat het configuratieoverzicht is bevestigd' {
            Mock Confirm-InstallationConfiguration { $true }
            $report = Invoke-LeenlaptopUtility -Action Install -Interactive -InstallPath $TestDrive
            $report.ExitCode | Should Be 0
            Assert-MockCalled Install-UtilityPackage -Times 1 -Exactly -Scope It -ParameterFilter { $Config.DownloadsMaxAgeDays -eq 19 }
        }
        It 'toont het overzicht bij WhatIf zonder een extra bevestiging te vragen' {
            Mock Confirm-InstallationConfiguration { throw 'Mag niet worden aangeroepen' }
            Mock Show-InstallationConfiguration {}
            $report = Invoke-LeenlaptopUtility -Action Install -Interactive -InstallPath $TestDrive -WhatIf
            $report.Results[0].Status | Should Be 'Planned'
            Assert-MockCalled Show-InstallationConfiguration -Times 1 -Exactly -Scope It
            Assert-MockCalled Install-UtilityPackage -Times 0 -Exactly -Scope It
        }
    }

    Describe 'Definitieve bevestigingsvraag' {
        It 'kiest niet standaard voor installeren bij lege of ongeldige invoer' {
            Mock Write-Host {}
            $script:answers = New-Object 'System.Collections.Generic.Queue[string]'
            foreach ($answer in @('', 'misschien', 'n')) { $script:answers.Enqueue($answer) }
            Mock Read-Host { $script:answers.Dequeue() }
            (Confirm-InstallationConfiguration) | Should Be $false
            Assert-MockCalled Read-Host -Times 3 -Exactly -Scope It
        }
    }

    Describe 'Bestanden opschonen in TestDrive' {
        BeforeEach {
            $script:Deadline = $null
            $root = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
            New-Item $root -ItemType Directory | Out-Null
        }
        It 'verwijdert oude bestanden maar bewaart recente inhoud in een oude map' {
            $folder = New-Item (Join-Path $root 'old-folder') -ItemType Directory
            $old = New-Item (Join-Path $folder.FullName 'old.txt') -ItemType File
            $recent = New-Item (Join-Path $folder.FullName 'recent.txt') -ItemType File
            $old.LastWriteTime = (Get-Date).AddDays(-40)
            $folder.LastWriteTime = (Get-Date).AddDays(-40)
            $result = Remove-UtilityFolderItems $root 'Test' 7
            Test-Path $old.FullName | Should Be $false
            Test-Path $recent.FullName | Should Be $true
            Test-Path $folder.FullName | Should Be $true
            $result.Removed | Should Be 1
            $result.Status | Should Be 'Success'
        }
        It 'ruimt lege oude submappen op en bewaart de hoofdmap' {
            $folder = New-Item (Join-Path $root 'empty') -ItemType Directory
            $folder.LastWriteTime = (Get-Date).AddDays(-40)
            $result = Remove-UtilityFolderItems $root 'Test' 7
            Test-Path $folder.FullName | Should Be $false
            Test-Path $root | Should Be $true
        }
        It 'raakt de bestemming van een junction niet aan' {
            $outside = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
            New-Item $outside -ItemType Directory | Out-Null
            $keep = New-Item (Join-Path $outside 'keep.txt') -ItemType File
            $junction = Join-Path $root 'junction'
            New-Item -Path $junction -ItemType Junction -Target $outside | Out-Null
            try {
                $result = Remove-UtilityFolderItems $root 'Test'
                Test-Path $keep.FullName | Should Be $true
                $result.Removed | Should Be 0
                $result.Status | Should Be 'Partial'
                { Assert-SafeRoot (Join-Path $junction 'not-created') } | Should Throw
            } finally { [IO.Directory]::Delete($junction) }
        }
        It 'meldt gedeeltelijk succes bij een vergrendeld bestand' {
            $file = New-Item (Join-Path $root 'locked.txt') -ItemType File
            $handle = [IO.File]::Open($file.FullName, 'Open', 'ReadWrite', 'None')
            try {
                $result = Remove-UtilityFolderItems $root 'Test'
                $result.Status | Should Be 'Partial'
                $result.Failed | Should Be 1
            } finally { $handle.Dispose() }
        }
        It 'stopt voor verwijdering als de tijdslimiet verstreken is' {
            $file = New-Item (Join-Path $root 'keep.txt') -ItemType File
            $script:Deadline = [DateTime]::UtcNow.AddSeconds(-1)
            $result = Remove-UtilityFolderItems $root 'Test'
            $result.Status | Should Be 'Failed'
            Test-Path $file.FullName | Should Be $true
            $script:Deadline = $null
        }
        It 'weigert een tweede uitvoerder en geeft de lock daarna vrij' {
            $lock = Enter-UtilityLock $root
            try { { Enter-UtilityLock $root } | Should Throw }
            finally { $lock.Dispose() }
            $next = Enter-UtilityLock $root
            $next.Dispose()
        }
    }

    Describe 'Veilige acties en resultaten' {
        BeforeEach {
            $script:Deadline = $null
            $install = Join-Path $TestDrive 'not-installed'
            Mock Read-UtilityConfiguration { @{ Config = (Get-DefaultConfiguration); Source = 'test'; Legacy = $false } }
            Mock Get-CurrentUserSid { 'S-1-5-21-1-2-3-1001' }
            Mock Get-CleanupPlan { @{ Name = 'Browser'; Kind = 'Browser'; Browser = 'chrome'; Admin = $false } }
            Mock Install-UtilityPackage { throw 'Installatie mag niet worden aangeroepen' }
            Mock Invoke-CleanupStep { throw 'Opschoning mag niet worden aangeroepen' }
            Mock Enter-UtilityLock { throw 'Geen lockbestand aanmaken' }
            Mock Write-UtilityReport { throw 'Geen rapport schrijven' }
        }
        It 'wijzigt niets bij Check' {
            $result = Invoke-LeenlaptopUtility -Action Check -InstallPath $install
            $result.ExitCode | Should Be 2
            Assert-MockCalled Install-UtilityPackage -Times 0 -Exactly
            Assert-MockCalled Invoke-CleanupStep -Times 0 -Exactly
            Assert-MockCalled Enter-UtilityLock -Times 0 -Exactly
            Assert-MockCalled Write-UtilityReport -Times 0 -Exactly
        }
        It 'wijzigt niets bij Cleanup WhatIf, ook voor installatie' {
            $result = Invoke-LeenlaptopUtility -Action Cleanup -InstallPath $install -WhatIf
            $result.Status | Should Be 'Planned'
            Assert-MockCalled Invoke-CleanupStep -Times 0 -Exactly
            Assert-MockCalled Enter-UtilityLock -Times 0 -Exactly
            Assert-MockCalled Write-UtilityReport -Times 0 -Exactly
        }
        It 'wijzigt niets bij Install WhatIf' {
            Mock Resolve-TargetUser { @{ Sid = 'S-1-5-21-1-2-3-1001'; ProfilePath = $TestDrive } }
            $result = Invoke-LeenlaptopUtility -Action Install -InstallPath $install -TargetUser test -WhatIf
            $result.Status | Should Be 'Planned'
            Assert-MockCalled Install-UtilityPackage -Times 0 -Exactly
        }
        It 'weigert opschoning vanuit een ander account' {
            Mock Read-UtilityConfiguration {
                $config = Get-DefaultConfiguration
                $config.TargetUserSid = 'S-1-5-21-1-2-3-1002'
                @{ Config = $config; Source = 'test'; Legacy = $false }
            }
            { Invoke-LeenlaptopUtility -Action Cleanup -InstallPath $install } | Should Throw
            { Invoke-LeenlaptopUtility -Action Cleanup -InstallPath $install -WhatIf } | Should Throw
            Assert-MockCalled Invoke-CleanupStep -Times 0 -Exactly
        }
        It 'onderscheidt fouten en gedeeltelijk succes in exitcodes' {
            Get-ResultExitCode @((New-StepResult 'A' 'Success')) | Should Be 0
            Get-ResultExitCode @((New-StepResult 'A' 'Partial')) | Should Be 2
            Get-ResultExitCode @((New-StepResult 'A' 'Success'), (New-StepResult 'B' 'Failed')) | Should Be 1
            Get-ResultExitCode @((New-StepResult 'A' 'Success'), (New-StepResult 'B' 'Planned')) | Should Be 2
        }
        It 'laat een hashfout niet doorgaan als een geslaagde kopie' {
            Mock Copy-Item {}
            Mock Get-FileHash { @{ Hash = 'A' } } -ParameterFilter { $LiteralPath -eq 'source' }
            Mock Get-FileHash { @{ Hash = 'B' } } -ParameterFilter { $LiteralPath -eq 'destination' }
            { Copy-VerifiedFile source destination } | Should Throw
        }
        It 'rapporteert gedeeltelijke opschoning als gedeeltelijk in plaats van succes' {
            $install = Join-Path $TestDrive 'partial-run'
            New-Item $install -ItemType Directory -Force | Out-Null
            '{}' | Set-Content (Join-Path $install 'config.json')
            Mock Read-UtilityConfiguration {
                $config = Get-DefaultConfiguration
                $config.TargetUserSid = 'S-1-5-21-1-2-3-1001'
                @{ Config = $config; Source = 'test'; Legacy = $false }
            }
            Mock Test-InstalledPackage {}
            Mock Enter-UtilityLock { [IO.File]::Open((Join-Path $TestDrive 'partial.lock'), 'OpenOrCreate', 'ReadWrite', 'None') }
            Mock Invoke-CleanupStep { New-StepResult 'Browser' 'Partial' -Failed 1 }
            Mock Update-UtilityRetention {}
            Mock Write-UtilityReport {}
            $result = Invoke-LeenlaptopUtility -Action Cleanup -InstallPath $install
            $result.Status | Should Be 'Partial'
            $result.ExitCode | Should Be 2
            Assert-MockCalled Write-UtilityReport -Times 1 -Exactly -Scope It
            Assert-MockCalled Write-UtilityReport -Times 1 -Exactly -Scope It -ParameterFilter {
                $Report.PSObject.Properties.Name -notcontains 'Config' -and $Report.PSObject.Properties.Name -notcontains 'ConfigSource'
            }
        }
        It 'weigert een gebruikersmap buiten het lokale profiel' {
            { Assert-UserDataPath ([IO.Path]::GetPathRoot($env:USERPROFILE)) } | Should Throw
        }
    }

    Describe 'Installatieherstel met gemockte systeemacties' {
        BeforeEach {
            $script:Deadline = $null
            $caseRoot = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
            $source = Join-Path $caseRoot 'source'
            $destination = Join-Path $caseRoot 'LeenlaptopSchoonmaak'
            New-Item $source, $destination -ItemType Directory -Force | Out-Null
            foreach ($name in $script:PackageFiles) { 'new package' | Set-Content (Join-Path $source $name) }
            'old script' | Set-Content (Join-Path $destination 'LeenlaptopSchoonmaak.ps1')
            'old config' | Set-Content (Join-Path $destination 'config.json')
            'old legacy script' | Set-Content (Join-Path $destination 'opstart-script.ps1')
            $config = Get-DefaultConfiguration
            $config.TargetUserSid = 'S-1-5-21-1-2-3-1001'
            Mock Set-UtilityPermissions {}
            Mock Set-UtilityFilePermissions {}
            Mock Set-Acl {}
            Mock Get-UtilityShortcutPath { Join-Path $TestDrive 'mock-shortcut.lnk' }
            Mock Get-ScheduledTask { $null }
            Mock Register-ScheduledTask {}
            Mock Unregister-ScheduledTask {}
            Mock Set-UtilityTask {}
            Mock Get-UtilityTaskSecurityDescriptor { 'D:P(A;;GA;;;SY)(A;;GA;;;BA)' }
            Mock Set-UtilityTaskPermissions {}
            Mock Set-UtilityShortcut {}
        }
        It 'installeert met config.json zonder het voorbeeldbestand en controleert daarna de integriteit' {
            $config.RunAtLogon = $true
            $config | ConvertTo-Json -Depth 5 | Set-Content (Join-Path $source 'config.json')
            Test-Path (Join-Path $source 'config.example.json') | Should Be $false
            $loaded = Read-UtilityConfiguration $source $destination (Join-Path $source 'config.json')
            $results = @(Install-UtilityPackage $source $destination $loaded.Config)
            Get-ResultExitCode $results | Should Be 0
            { Test-InstalledPackage $destination } | Should Not Throw
            $saved = Get-Content (Join-Path $destination 'config.json') -Raw | ConvertFrom-Json
            $saved.RunAtLogon | Should Be $true
            $manifest = Get-Content (Join-Path $destination 'manifest.json') -Raw | ConvertFrom-Json
            ($manifest.Hashes.PSObject.Properties.Name -contains 'config.example.json') | Should Be $false
        }
        It 'blijft ontbrekende programmabestanden weigeren voordat iets wordt vervangen' {
            Remove-Item -LiteralPath (Join-Path $source 'LeenlaptopSchoonmaak.psm1')
            { Install-UtilityPackage $source $destination $config } | Should Throw
            (Get-Content (Join-Path $destination 'LeenlaptopSchoonmaak.ps1') -Raw).Trim() | Should Be 'old script'
            Assert-MockCalled Set-UtilityTask -Times 0 -Exactly -Scope It
        }
        It 'herstelt bestanden en behoudt het oude script wanneer taakregistratie faalt' {
            Mock Set-UtilityTask { throw 'task failed' }
            { Install-UtilityPackage $source $destination $config } | Should Throw
            (Get-Content (Join-Path $destination 'LeenlaptopSchoonmaak.ps1') -Raw).Trim() | Should Be 'old script'
            (Get-Content (Join-Path $destination 'config.json') -Raw).Trim() | Should Be 'old config'
            Test-Path (Join-Path $destination 'opstart-script.ps1') | Should Be $true
            Test-Path (Join-Path $destination 'LeenlaptopSchoonmaak.psm1') | Should Be $false
            Assert-MockCalled Unregister-ScheduledTask -Times 0 -Exactly
            $lock = Enter-UtilityLock $destination
            $lock.Dispose()
        }
        It 'herstelt ook de oude geplande taak bij een mislukte update' {
            Mock Get-ScheduledTask { @{ TaskName = 'LeenlaptopSchoonmaak' } } -ParameterFilter { $TaskName -eq 'LeenlaptopSchoonmaak' }
            Mock Export-ScheduledTask { '<Task>old</Task>' }
            Mock Set-UtilityTask { throw 'task failed' }
            { Install-UtilityPackage $source $destination $config } | Should Throw
            Assert-MockCalled Register-ScheduledTask -Times 1 -Exactly -ParameterFilter { $Xml -eq '<Task>old</Task>' }
            Assert-MockCalled Set-UtilityTaskPermissions -Times 1 -Exactly -Scope It -ParameterFilter { $SecurityDescriptor -eq 'D:P(A;;GA;;;SY)(A;;GA;;;BA)' }
        }
        It 'verwijdert oude namen pas nadat de nieuwe voorzieningen geslaagd zijn' {
            $results = @(Install-UtilityPackage $source $destination $config)
            Get-ResultExitCode $results | Should Be 0
            Test-Path (Join-Path $destination 'opstart-script.ps1') | Should Be $false
            Test-Path (Join-Path $destination 'backups') | Should Be $true
            $saved = Get-Content (Join-Path $destination 'config.json') -Raw | ConvertFrom-Json
            $saved.TargetUserSid | Should Be 'S-1-5-21-1-2-3-1001'
            Assert-MockCalled Set-UtilityTask -Times 1 -Exactly -Scope It
        }
    }

    Describe 'Wi-Fi en retentie zonder echte systeemacties' {
        BeforeEach { $script:Deadline = $null }
        It 'behoudt toegestane Wi-Fi-profielen en telt mislukte verwijderingen' {
            Mock Get-WiFiProfileNames { @('kantoor', 'gast', 'vergrendeld') }
            Mock Remove-WiFiProfileName { 1 }
            Mock Remove-WiFiProfileName { throw 'locked' } -ParameterFilter { $Name -eq 'vergrendeld' }
            $result = Clear-UtilityWiFi @('kantoor')
            $result.Removed | Should Be 1
            $result.Failed | Should Be 1
            $result.Status | Should Be 'Partial'
            Assert-MockCalled Remove-WiFiProfileName -Times 0 -Exactly -Scope It -ParameterFilter { $Name -eq 'kantoor' }
        }
        It 'past retentie toe op historie en afzonderlijke actuele logregels' {
            $install = Join-Path $TestDrive 'retention'
            $state = Join-Path $install 'state'
            New-Item $state -ItemType Directory -Force | Out-Null
            $history = New-Item (Join-Path $state 'run_old.json') -ItemType File
            $history.LastWriteTime = (Get-Date).AddDays(-60)
            $old = '{0:o} Cleanup Success exit=0' -f [DateTime]::UtcNow.AddDays(-60)
            $recent = '{0:o} Cleanup Partial exit=2' -f [DateTime]::UtcNow
            @($old, $recent) | Set-Content (Join-Path $state 'log.txt')
            Mock Test-Administrator { $false }
            Update-UtilityRetention $install (Get-DefaultConfiguration)
            Test-Path $history.FullName | Should Be $false
            $lines = @(Get-Content (Join-Path $state 'log.txt'))
            $lines.Count | Should Be 1
            $lines[0] | Should Be $recent
        }
        It 'schrijft leesbare tekst en geldige JSON zonder configuratiegegevens' {
            $install = Join-Path $TestDrive 'report'
            $state = Join-Path $install 'state'
            New-Item $state -ItemType Directory -Force | Out-Null
            $report = [pscustomobject]@{
                Version = 'test'; Action = 'Cleanup'; Status = 'Partial'; ExitCode = 2
                StartedAt = [DateTime]::UtcNow.ToString('o'); DurationSeconds = 1
                Results = @((New-StepResult 'Test' 'Partial' -Failed 1))
            }
            Write-UtilityReport $install $report
            $json = Get-Content (Join-Path $state 'laatste_status.json') -Raw | ConvertFrom-Json
            $json.ExitCode | Should Be 2
            $lines = @(Get-Content (Join-Path $state 'laatste_status.txt'))
            $lines[1] | Should Be 'Actie: Cleanup'
            $lines[2] | Should Be 'Status: Partial'
        }
        It 'behandelt Wi-Fi-uitzonderingen letterlijk, inclusief wildcards en hoofdletters' {
            Mock Get-WiFiProfileNames { @('*', 'Kantoor', 'kantoor') }
            Mock Remove-WiFiProfileName { 1 }
            $result = Clear-UtilityWiFi @('Kantoor')
            $result.Removed | Should Be 2
            Assert-MockCalled Remove-WiFiProfileName -Times 1 -Exactly -Scope It -ParameterFilter { $Name -eq '*' }
            Assert-MockCalled Remove-WiFiProfileName -Times 0 -Exactly -Scope It -ParameterFilter { $Name -ceq 'Kantoor' }
        }
    }

    Describe 'Draaiende browsers met uitsluitend gesimuleerde processen' {
        BeforeEach {
            $script:Deadline = $null
            $script:browserRecords = @{}
            $script:browserSid = 'S-1-5-21-1-2-3-1001'
            $script:stopMode = 'normal'
            foreach ($id in @(101, 102)) {
                $script:browserRecords[$id] = New-TestBrowserProcess $id $script:browserSid ([DateTime]::UtcNow.AddMinutes(-5))
            }
            Mock Start-Sleep {}
            Mock Get-CimInstance {
                if ($Filter -match '^ProcessId = (\d+)$') { return $script:browserRecords[[int]$Matches[1]] }
                @($script:browserRecords.Values)
            }
            Mock Invoke-CimMethod { @{ ReturnValue = 0; Sid = $InputObject.OwnerSid } }
            Mock Stop-Process { throw 'Geen echte processen stoppen' }
            Mock Stop-UtilityBrowserProcess {
                if ($script:stopMode -eq 'denied') { throw 'Access denied' }
                $script:browserRecords.Remove([int]$Record.ProcessId)
                if ($script:stopMode -eq 'parent-exit') { $script:browserRecords.Remove(102) }
                if ($script:stopMode -eq 'respawn' -and $Record.ProcessId -eq 101) {
                    $script:browserRecords[104] = New-TestBrowserProcess 104 $script:browserSid
                }
            }
        }
        It 'blijft werken wanneer het hoofdproces zijn kindprocessen tegelijk afsluit' {
            $script:stopMode = 'parent-exit'
            { Stop-UtilityBrowserProcesses chrome $script:browserSid 3 } | Should Not Throw
            Assert-MockCalled Stop-UtilityBrowserProcess -Times 1 -Exactly -Scope It
        }
        It 'controleert opnieuw dat alle browserprocessen verdwenen zijn' {
            { Stop-UtilityBrowserProcesses chrome $script:browserSid 3 } | Should Not Throw
            Assert-MockCalled Get-CimInstance -Times 4 -Exactly -Scope It -ParameterFilter { $Filter -eq "Name = 'chrome.exe'" }
        }
        It 'inventariseert opnieuw en stopt nieuw verschenen achtergrondprocessen' {
            $script:stopMode = 'respawn'
            { Stop-UtilityBrowserProcesses chrome $script:browserSid 3 } | Should Not Throw
            Assert-MockCalled Stop-UtilityBrowserProcess -Times 1 -Exactly -Scope It -ParameterFilter { $Record.ProcessId -eq 104 }
        }
        It 'laat processen van andere gebruikers ongemoeid' {
            $script:browserRecords[102].OwnerSid = 'S-1-5-21-1-2-3-1002'
            { Stop-UtilityBrowserProcesses chrome $script:browserSid 3 } | Should Not Throw
            Assert-MockCalled Stop-UtilityBrowserProcess -Times 0 -Exactly -Scope It -ParameterFilter { $Record.ProcessId -eq 102 }
        }
        It 'weigert een niet controleerbare eigenaar wanneer het proces nog bestaat' {
            Mock Invoke-CimMethod { @{ ReturnValue = 2; Sid = '' } }
            { Stop-UtilityBrowserProcesses chrome $script:browserSid 3 } | Should Throw
            Assert-MockCalled Stop-Process -Times 0 -Exactly -Scope It
        }
        It 'stopt niet wanneer een PID inmiddels bij een ander proces hoort' {
            Mock Get-CimInstance {
                $script:browserRecords[101] = New-TestBrowserProcess 101 'S-1-5-21-1-2-3-1002'
                $script:browserRecords[101]
            } -ParameterFilter { $Filter -eq 'ProcessId = 101' }
            { Stop-UtilityBrowserProcesses chrome $script:browserSid 3 } | Should Not Throw
            Assert-MockCalled Stop-UtilityBrowserProcess -Times 0 -Exactly -Scope It -ParameterFilter { $Record.ProcessId -eq 101 }
        }
        It 'stopt de stap bij blijvende toegangsweigering' {
            $script:stopMode = 'denied'
            { Stop-UtilityBrowserProcesses chrome $script:browserSid 3 } | Should Throw
        }
        It 'respecteert de globale tijdslimiet voordat een proces wordt gestopt' {
            $script:Deadline = [DateTime]::UtcNow.AddSeconds(-1)
            { Stop-UtilityBrowserProcesses chrome $script:browserSid 3 } | Should Throw
            Assert-MockCalled Stop-Process -Times 0 -Exactly -Scope It
        }
    }

    Describe 'Procesidentiteit zonder processen te stoppen' {
        BeforeEach {
            $script:testProcess = [Diagnostics.Process]::GetCurrentProcess()
            $script:testStart = $script:testProcess.StartTime
            Mock Get-Process { $script:testProcess }
            Mock Stop-Process {}
            Mock Get-CimInstance { $null }
        }
        It 'gebruikt het gecontroleerde procesobject in plaats van alleen een PID' {
            Stop-UtilityBrowserProcess ([pscustomobject]@{ ProcessId = 50000; CreationDate = $script:testStart })
            Assert-MockCalled Stop-Process -Times 1 -Exactly -Scope It -ParameterFilter { $InputObject[0] -is [Diagnostics.Process] -and $Force }
        }
        It 'behandelt een inmiddels verdwenen proces niet als een fout' {
            Mock Stop-Process { throw 'Process already exited' }
            { Stop-UtilityBrowserProcess ([pscustomobject]@{ ProcessId = 50000; CreationDate = $script:testStart }) } | Should Not Throw
        }
        It 'stopt niet wanneer de beheerde starttijd niet overeenkomt' {
            Stop-UtilityBrowserProcess ([pscustomobject]@{ ProcessId = 50000; CreationDate = $script:testStart.AddMinutes(-1) })
            Assert-MockCalled Stop-Process -Times 0 -Exactly -Scope It
        }
    }

    Describe 'Browseropslag met uitsluitend testprofielen' {
        BeforeEach {
            $script:Deadline = $null
            $savedEnvironment = @{}
            foreach ($name in @('USERPROFILE', 'LOCALAPPDATA', 'APPDATA')) {
                $savedEnvironment[$name] = [Environment]::GetEnvironmentVariable($name, 'Process')
            }
            $fakeProfile = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
            $env:USERPROFILE = $fakeProfile
            $env:LOCALAPPDATA = Join-Path $fakeProfile 'AppData\Local'
            $env:APPDATA = Join-Path $fakeProfile 'AppData\Roaming'
            Mock Get-CurrentUserSid { 'S-1-5-21-1-2-3-1001' }
            Mock Get-CimInstance { @() }
            Mock Stop-Process { throw 'Geen echte processen stoppen' }
            Mock Start-Sleep {}
        }
        AfterEach {
            foreach ($name in $savedEnvironment.Keys) { [Environment]::SetEnvironmentVariable($name, $savedEnvironment[$name], 'Process') }
        }
        It 'wist alle Chrome-testprofielen, ook profielen met een aangepaste naam' {
            $root = Join-Path $env:LOCALAPPDATA 'Google\Chrome\User Data'
            foreach ($name in @('Default', 'Profile 1', 'Custom')) {
                $folder = Join-Path $root $name
                New-Item $folder -ItemType Directory -Force | Out-Null
                'fake cookies' | Set-Content (Join-Path $folder 'Cookies')
            }
            $result = Clear-UtilityBrowser chrome 3
            $result.Status | Should Be 'Success'
            @(Get-ChildItem $root -Force).Count | Should Be 0
            Assert-MockCalled Stop-Process -Times 0 -Exactly -Scope It
        }
        It 'wist Firefox-testprofielen en hun profielregistratie samen' {
            $root = Join-Path $env:APPDATA 'Mozilla\Firefox'
            New-Item (Join-Path $root 'Profiles\test.default') -ItemType Directory -Force | Out-Null
            'fake profile registration' | Set-Content (Join-Path $root 'profiles.ini')
            'fake preferences' | Set-Content (Join-Path $root 'Profiles\test.default\prefs.js')
            $result = Clear-UtilityBrowser firefox 3
            $result.Status | Should Be 'Success'
            @(Get-ChildItem $root -Force).Count | Should Be 0
        }
        It 'wist de lokale opslag van een Edge-testprofiel' {
            $root = Join-Path $env:LOCALAPPDATA 'Microsoft\Edge\User Data'
            New-Item (Join-Path $root 'Default') -ItemType Directory -Force | Out-Null
            'fake history' | Set-Content (Join-Path $root 'Default\History')
            $result = Clear-UtilityBrowser msedge 3
            $result.Status | Should Be 'Success'
            @(Get-ChildItem $root -Force).Count | Should Be 0
        }
        It 'verwijdert niets wanneer de browser niet kan worden afgesloten' {
            Mock Stop-UtilityBrowserProcesses { throw 'Browser blijft draaien' }
            Mock Remove-UtilityFolderItems { throw 'Mag niet worden aangeroepen' }
            { Clear-UtilityBrowser chrome 3 } | Should Throw
            Assert-MockCalled Remove-UtilityFolderItems -Times 0 -Exactly -Scope It
        }
        It 'bewaart het aantal verwijderde bestanden als afsluiten bij een herpoging mislukt' {
            $script:stopPass = 0
            Mock Stop-UtilityBrowserProcesses { $script:stopPass++; if ($script:stopPass -gt 1) { throw 'Browser start opnieuw' } }
            Mock Remove-UtilityFolderItems { New-StepResult 'chrome' 'Partial' -Removed 2 -Failed 1 }
            $result = Clear-UtilityBrowser chrome 3
            $result.Status | Should Be 'Partial'
            $result.Removed | Should Be 2
        }
        It 'probeert vergrendelde bestanden opnieuw zonder eerdere fouten dubbel te tellen' {
            Mock Stop-UtilityBrowserProcesses {}
            $script:deletePass = 0
            Mock Remove-UtilityFolderItems {
                $script:deletePass++
                if ($script:deletePass -eq 1) { return (New-StepResult 'chrome' 'Partial' -Removed 2 -Failed 1) }
                New-StepResult 'chrome' 'Success' -Removed 1
            }
            $result = Clear-UtilityBrowser chrome 3
            $result.Status | Should Be 'Success'
            $result.Removed | Should Be 3
            $result.Failed | Should Be 0
        }
        It 'blijft een niet verwijderbaar bestand na de herpogingen als gedeeltelijk resultaat melden' {
            Mock Stop-UtilityBrowserProcesses {}
            Mock Remove-UtilityFolderItems { New-StepResult 'chrome' 'Partial' -Failed 1 }
            $result = Clear-UtilityBrowser chrome 3
            $result.Status | Should Be 'Partial'
            $result.Failed | Should Be 1
            Assert-MockCalled Remove-UtilityFolderItems -Times 3 -Exactly -Scope It
        }
        It 'rapporteert opnieuw starten tijdens opschoning niet als succes' {
            Mock Stop-UtilityBrowserProcesses {}
            Mock Remove-UtilityFolderItems { New-StepResult 'chrome' 'Success' -Removed 2 }
            Mock Get-UtilityBrowserProcesses { [pscustomobject]@{ ProcessId = 999 } }
            $result = Clear-UtilityBrowser chrome 3
            $result.Status | Should Be 'Partial'
            $result.Failed | Should Be 1
        }
    }

    Describe 'WLAN-interop zonder Windows WLAN-aanroepen' {
        BeforeEach {
            if (-not ('Leenlaptop.WlanProfiles' -as [type])) { Add-Type -Path (Join-Path (Split-Path $PSScriptRoot) 'WlanProfiles.cs') }
        }
        It 'gebruikt de juiste native structuurafmetingen' {
            $type = 'Leenlaptop.WlanProfiles' -as [type]
            $interfaceType = $type.GetNestedType('InterfaceInfo', [Reflection.BindingFlags]::NonPublic)
            $profileType = $type.GetNestedType('ProfileInfo', [Reflection.BindingFlags]::NonPublic)
            [Runtime.InteropServices.Marshal]::SizeOf([Activator]::CreateInstance($interfaceType)) | Should Be 532
            [Runtime.InteropServices.Marshal]::SizeOf([Activator]::CreateInstance($profileType)) | Should Be 516
        }
        It 'marshalt profielnamen als Unicode voor letterlijke verwijdering' {
            $type = 'Leenlaptop.WlanProfiles' -as [type]
            $method = $type.GetMethod('WlanDeleteProfile', [Reflection.BindingFlags]'NonPublic,Static')
            $attribute = $method.GetCustomAttributes([Runtime.InteropServices.DllImportAttribute], $false)[0]
            $attribute.CharSet | Should Be ([Runtime.InteropServices.CharSet]::Unicode)
            $attribute.Value | Should Be 'wlanapi.dll'
        }
    }
}
