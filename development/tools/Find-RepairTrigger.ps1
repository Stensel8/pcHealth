#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Finds what the Settings "Reinstall now" button calls under the hood.

.DESCRIPTION
    Windows publishes no API for the "Fix problems using Windows Update" repair,
    so pcHealth presses the real button through UI Automation. This script looks
    for something better: the binary, verb or registry flag the button actually
    uses, so the repair could be started directly instead.

    Everything here is read-only. Nothing in this script starts a repair -- the
    Watch mode asks you to press the button yourself and reports what moved.

.PARAMETER Mode
    Strings scans the likely binaries for revealing text.
    Watch records what happens while you press the button.
    Both runs Strings and then Watch.

.PARAMETER WatchSeconds
    How long Watch records after you are asked to press the button.

.EXAMPLE
    .\Find-RepairTrigger.ps1 -Mode Strings

.EXAMPLE
    .\Find-RepairTrigger.ps1 -Mode Watch -WatchSeconds 180
#>
[CmdletBinding()]
param(
    [ValidateSet('Strings', 'Watch', 'Both')]
    [string]$Mode = 'Both',

    [ValidateRange(30, 900)]
    [int]$WatchSeconds = 150
)

Set-StrictMode -Version Latest

$WatchSource = 'pcHealthProcessWatch'

# Words worth finding in a binary that knows about this repair.
$InterestingPattern = 'Reinstall|CloudDownload|RepairVersion|repair version|SelfHeal|Self-heal|' +
                      'RecoveryReinstall|FixProblem|ms-settings:recovery|StartRepair|RemediationRequired|' +
                      'ms-cxh'

function Get-BinaryString {
    <#
        .SYNOPSIS
            Pulls printable runs out of a file and returns the ones that match.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$Pattern,
        [int]$MinimumLength = 6
    )

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return }

    try {
        $bytes = [System.IO.File]::ReadAllBytes($Path)
    }
    catch [System.IO.IOException] {
        Write-Warning "Could not read $Path : $($_.Exception.Message)"
        return
    }
    catch [System.UnauthorizedAccessException] {
        Write-Warning "Access denied reading $Path"
        return
    }

    # A PE carries literals both as plain bytes and as UTF-16, so both decodings
    # are searched rather than guessing which one a given string used.
    $runPattern = "[\x20-\x7E]{$MinimumLength,}"
    foreach ($text in @(
        [System.Text.Encoding]::ASCII.GetString($bytes),
        [System.Text.Encoding]::Unicode.GetString($bytes)
    )) {
        foreach ($match in [regex]::Matches($text, $runPattern)) {
            if ($match.Value -match $Pattern) { Write-Output $match.Value }
        }
    }
}

function Get-UpdateRegistrySnapshot {
    <#
        .SYNOPSIS
            Flattens the Windows Update keys into comparable "key|name=value" lines.
    #>
    [CmdletBinding()]
    param()

    $roots = @(
        'HKLM:\SOFTWARE\Microsoft\WindowsUpdate',
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate'
    )

    foreach ($root in $roots) {
        if (-not (Test-Path -LiteralPath $root)) { continue }

        $keys = @($root) + @(
            Get-ChildItem -LiteralPath $root -Recurse -ErrorAction SilentlyContinue |
                Select-Object -ExpandProperty PSPath
        )

        foreach ($key in $keys) {
            $values = Get-ItemProperty -LiteralPath $key -ErrorAction SilentlyContinue
            if ($null -eq $values) { continue }

            foreach ($property in $values.PSObject.Properties) {
                if ($property.Name -like 'PS*') { continue }
                Write-Output ('{0}|{1}={2}' -f $key, $property.Name, ($property.Value -join ','))
            }
        }
    }
}

function Get-OrchestratorTask {
    <#
        .SYNOPSIS
            Lists the Update Orchestrator task files, read straight off disk so
            no Windows-only cmdlet is needed.
    #>
    [CmdletBinding()]
    param()

    $tasks = Join-Path $env:SystemRoot 'System32\Tasks\Microsoft\Windows\UpdateOrchestrator'
    if (-not (Test-Path -LiteralPath $tasks)) { return }

    Get-ChildItem -LiteralPath $tasks -Recurse -File -ErrorAction SilentlyContinue |
        Select-Object -ExpandProperty FullName
}

function Invoke-StringScan {
    [CmdletBinding()]
    param()

    Write-Host ''
    Write-Host '== Scanning binaries for repair-related text ==' -ForegroundColor Cyan

    $system32 = Join-Path $env:SystemRoot 'System32'
    $candidates = @(
        'SystemSettings.Handlers.dll',
        'SystemSettings.DataModel.dll',
        'usoclient.exe',
        'UsoCore.dll',
        'MoUsoCoreWorker.exe',
        'usocoreworker.exe',
        'SystemReset.exe',
        'ResetEngine.dll',
        'ResetEngOnline.dll'
    ) | ForEach-Object { Join-Path $system32 $_ }

    # The reset and recovery flows run inside the Cloud Experience Host, which
    # is also where ms-cxh: verbs are handled, so its binaries are worth reading.
    $folders = @(
        (Join-Path $env:SystemRoot 'ImmersiveControlPanel'),
        (Join-Path $env:SystemRoot 'SystemApps')
    )
    foreach ($folder in $folders) {
        if (-not (Test-Path -LiteralPath $folder)) { continue }
        $candidates += Get-ChildItem -LiteralPath $folder -Filter '*.dll' -Recurse -ErrorAction SilentlyContinue |
            Where-Object { $_.Directory.Name -notlike '*Edge*' } |
            Select-Object -ExpandProperty FullName
    }

    foreach ($candidate in $candidates) {
        $hits = @(Get-BinaryString -Path $candidate -Pattern $InterestingPattern | Sort-Object -Unique)
        if ($hits.Count -eq 0) { continue }

        Write-Host ''
        Write-Host ("--- {0} ({1} hits)" -f (Split-Path -Leaf $candidate), $hits.Count) -ForegroundColor Yellow
        $hits | ForEach-Object { Write-Host "    $_" }
    }
}

function Invoke-ProtocolScan {
    <#
        .SYNOPSIS
            Lists the ms- URI schemes this machine actually registers.

        .DESCRIPTION
            Answers the "there must be a protocol for it" hunch with the
            machine's own list instead of guesswork. Nothing is launched: some
            of these verbs start destructive flows, so they are only printed.
    #>
    [CmdletBinding()]
    param()

    Write-Host ''
    Write-Host '== Registered ms- URI schemes ==' -ForegroundColor Cyan
    Write-Host 'Read-only. Do not fire these blindly: some of them reset the PC.' -ForegroundColor DarkYellow

    $classes = 'Registry::HKEY_CLASSES_ROOT'
    Get-ChildItem -LiteralPath $classes -ErrorAction SilentlyContinue |
        Where-Object { $_.PSChildName -like 'ms-*' } |
        ForEach-Object {
            $values = Get-ItemProperty -LiteralPath $_.PSPath -ErrorAction SilentlyContinue
            if ($null -eq $values -or -not $values.PSObject.Properties.Name.Contains('URL Protocol')) { return }

            $commandKey = Join-Path $_.PSPath 'shell\open\command'
            $command = (Get-ItemProperty -LiteralPath $commandKey -ErrorAction SilentlyContinue).'(default)'
            Write-Host ('    {0,-34} {1}' -f $_.PSChildName, $command)
        }
}

function Invoke-ButtonWatch {
    [CmdletBinding()]
    param([int]$Seconds)

    Write-Host ''
    Write-Host '== Recording what the button does ==' -ForegroundColor Cyan

    $registryBefore = @(Get-UpdateRegistrySnapshot)
    $tasksBefore = @(Get-OrchestratorTask)
    Write-Host ("Baseline: {0} registry values, {1} orchestrator tasks." -f $registryBefore.Count, $tasksBefore.Count)

    Register-CimIndicationEvent -ClassName 'Win32_ProcessStartTrace' -SourceIdentifier $WatchSource | Out-Null

    Write-Host ''
    Write-Host 'Now open Settings > System > Recovery and press "Reinstall now".' -ForegroundColor Green
    Write-Host ("Recording for {0} seconds. Press Ctrl+C to stop early." -f $Seconds)

    try {
        Start-Sleep -Seconds $Seconds
    }
    finally {
        $events = @(Get-Event -SourceIdentifier $WatchSource -ErrorAction SilentlyContinue)
        Unregister-Event -SourceIdentifier $WatchSource -ErrorAction SilentlyContinue
        Remove-Event -SourceIdentifier $WatchSource -ErrorAction SilentlyContinue
    }

    Write-Host ''
    Write-Host '--- Processes started while recording ---' -ForegroundColor Yellow
    if ($events.Count -eq 0) {
        Write-Host '    (none captured)'
    }
    else {
        $events |
            ForEach-Object { $_.SourceEventArgs.NewEvent.ProcessName } |
            Group-Object |
            Sort-Object -Property Count -Descending |
            ForEach-Object { Write-Host ('    {0,-40} x{1}' -f $_.Name, $_.Count) }
    }

    Write-Host ''
    Write-Host '--- Windows Update registry values that changed ---' -ForegroundColor Yellow
    $registryAfter = @(Get-UpdateRegistrySnapshot)
    $registryDelta = @(Compare-Object -ReferenceObject $registryBefore -DifferenceObject $registryAfter)
    if ($registryDelta.Count -eq 0) {
        Write-Host '    (nothing changed)'
    }
    else {
        $registryDelta | ForEach-Object {
            $sign = if ($_.SideIndicator -eq '=>') { 'new' } else { 'gone' }
            Write-Host ('    [{0}] {1}' -f $sign, $_.InputObject)
        }
    }

    Write-Host ''
    Write-Host '--- Update Orchestrator tasks that appeared ---' -ForegroundColor Yellow
    $tasksDelta = @(Compare-Object -ReferenceObject $tasksBefore -DifferenceObject @(Get-OrchestratorTask) |
        Where-Object { $_.SideIndicator -eq '=>' })
    if ($tasksDelta.Count -eq 0) {
        Write-Host '    (none)'
    }
    else {
        $tasksDelta | ForEach-Object { Write-Host ('    {0}' -f $_.InputObject) }
    }
}

Write-Host 'pcHealth -- repair trigger hunt (read-only)' -ForegroundColor Cyan

if ($Mode -in @('Strings', 'Both')) {
    Invoke-ProtocolScan
    Invoke-StringScan
}
if ($Mode -in @('Watch', 'Both')) { Invoke-ButtonWatch -Seconds $WatchSeconds }

Write-Host ''
Write-Host 'Done. Send the output back so the findings can be turned into a direct call.' -ForegroundColor Cyan
