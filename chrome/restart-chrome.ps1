$plist = @()

# http://superuser.com/questions/727724/close-programs-from-the-command-line-windows
if (Get-Process chrome -EA ignore) {
    taskkill /im chrome.exe 2>&1 | Out-Null

    # As the link above explained, there will be chrome processes don't process WM_CLOSE message, but they will
    # be closed by chrome itself when all the windows are closed, we just need to wait for a while
    for ($i = 0; $i -lt 3; $i++) {
        Start-Sleep -Seconds 1
        [array] $plist = Get-Process chrome -EA ignore
        if (!$plist) {
            break
        }
    }
}

if ($plist) {
    # There are still chrome processes left over, let's kill them
    $plist | Stop-Process -EA ignore
    [array] $plist = Get-Process chrome -EA ignore
    if ($plist) {
        throw "Failed to close all chrome processes"
    }

    # When chrome is crashed/killed, it will prompt you to restore the session on next startup, which is very annoying.
    # So far there is no supported flags or command line switches to ask chrome to do not show the session restore prompt,
    # except for following hack which is to directly modifying the user preferences (which is a json file).
    $file = "$($env:LocalAppData)\Google\Chrome\User Data\Default\Preferences"
    $backup = $file + '.bak'
    if (!(Test-Path $backup)) { copy $file $backup } # only create backup when it doesn't exist, to avoid overwriting a good backup one second run

    $j = ConvertFrom-Json (Get-Content $file | Out-String)
    # Output current data as FYI
    [PsCustomObject] @{
        ExitType = $j.profile.exit_type
        ExitedCleanly = $j.profile.exited_cleanly
    }

    if ($j.profile.exit_type -eq 'Crashed' -OR !$j.profile.exited_cleanly) {
        $j.profile.exit_type = 'None' # case-sensitive!
        $j.profile.exited_cleanly = $true
        $j | ConvertTo-Json -Depth 99 | Out-File $file -Encoding UTF8
        Write-Host "Updated $file to remove crash state."
    }
}

start chrome
