<#

The minimal core bootstrap task.

* Designed for Windows Server 2012R2.
* Installs WMF5
* Downloads a 'setup.ps1'
* Sets up an 'on boot' task to run 'setup.ps1'
* Reboots!

#>
$Dir = "C:\cloud-automation"
Start-Transcript -Path $Dir\bootstrap.log -Append

# Install WMF5 without rebooting
$WMF5FileName = "Win8.1AndW2K12R2-KB3134758-x64.msu"
$WMF5BaseURL = "https://download.microsoft.com/download/2/C/6/2C6E1B4A-EBE5-48A6-B225-2D2058A9CEFB"
$WMF5TempDir = "${Env:WinDir}\Temp"
function Install-WMF5 {
    (New-Object -TypeName System.Net.webclient).DownloadFile("${WMF5BaseURL}/${WMF5FileName}", "${WMF5TempDir}\${WMF5FileName}")
    Start-Process -Wait -FilePath "${WMF5TempDir}\${WMF5FileName}" -ArgumentList '/quiet /norestart' -Verbose
}

$SetupURL = Get-Content "$Dir\setup.url" -Raw
$SetupFileName = "$Dir\setup.ps1"

# Set up a boot task
function Create-BootTask {
    if (Get-ScheduledTask -TaskName 'rsBoot' -ErrorAction SilentlyContinue) {
        return
    }
    $A = New-ScheduledTaskAction `
        -Execute "PowerShell.exe" `
        -Argument "-ExecutionPolicy Bypass -file $SetupFileName"
    $T = New-ScheduledTaskTrigger -AtStartup
    $P = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount
    $S = New-ScheduledTaskSettingsSet
    $D = New-ScheduledTask -Action $A -Principal $P -Trigger $T -Settings $S
    Register-ScheduledTask rsBoot -InputObject $D
}

# Fetch and store the Setup script
(New-Object -TypeName System.Net.webclient).DownloadFile($SetupURL, $SetupFileName)

Create-BootTask
Install-WMF5
Stop-Transcript
Restart-Computer -Force