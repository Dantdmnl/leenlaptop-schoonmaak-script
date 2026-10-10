Import-Module (Join-Path $PSScriptRoot '..\LeenlaptopSchoonmaak.psm1') -Force

InModuleScope LeenlaptopSchoonmaak {
    Describe 'Configuratie en migratie' {
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
    }
}
