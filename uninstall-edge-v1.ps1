## RIP Edge legacy app first
$edges = (Get-AppxPackage -AllUsers *MicrosoftEdge*).PackageFullName
$bloat = (Get-AppxProvisionedPackage -Online | Where-Object { $_.PackageName -like '*MicrosoftEdge*' }).PackageName
$users = ([wmi]"win32_userAccount.Domain='$env:userdomain',Name='$env:username'").SID, 'S-1-5-18'
$eoled = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Appx\AppxAllUserStore\EndOfLife'

foreach ($legacy in $bloat) {
    foreach ($user in $users) {
        New-Item "$eoled\$user\$legacy" -Force -ErrorAction SilentlyContinue
    }
    Remove-AppxProvisionedPackage -Online -PackageName $legacy -ErrorAction SilentlyContinue
}

foreach ($legacy in $edges) {
    foreach ($user in $users) {
        New-Item "$eoled\$user\$legacy" -Force -ErrorAction SilentlyContinue
    }
Try {
    Remove-AppxPackage -AllUsers -Package $legacy -ErrorAction Stop
}
Catch [System.Runtime.InteropServices.COMException] {
    # Handle or ignore the error
}
}

## remove ChrEdge lame uninstall block
$uninstall = '\Microsoft\Windows\CurrentVersion\Uninstall\Microsoft Edge'
foreach ($wow in '','\Wow6432Node') {
    'HKCU:','HKLM:' | ForEach-Object { Remove-ItemProperty -Path ($_ + $wow + $uninstall) -Name NoRemove -Force -ErrorAction SilentlyContinue }
}

## find all ChrEdge setup.exe
$setup = @()
"LocalApplicationData","ProgramFilesX86","ProgramFiles" | ForEach-Object {
    $setup += Get-ChildItem -Path "$([Environment]::GetFolderPath($_))\Microsoft\Edge*\setup.exe" -Recurse -ErrorAction SilentlyContinue
}

## compute ChrEdge uninstall arguments
$arg = @()
$u = '--uninstall'
$v = ' --verbose-logging --force-uninstall --delete-profile'
foreach ($l in '', ' --system-level') {
    foreach ($m in ' --msedge', '') {
        if ($m -eq '') {
            $arg += $u + $l + $v
        }
        else {
            '-beta', '-dev', '-internal', '-sxs', 'webview', '' | ForEach-Object {
                $arg += $u + $l + $m + $_ + $v
            }
        }
    }
}

## stop MSEdge, WebView2 before uninstall
Get-Process -Name msedge, msedgewebview2 -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue

## brute-run found ChrEdge setup.exe with uninstall args
foreach ($ChrEdge in $setup) {
    foreach ($purge in $arg) {
        Start-Process -FilePath "$ChrEdge" -ArgumentList "$purge" -NoNewWindow -Wait -ErrorAction SilentlyContinue
    }
}

## remove leftover shortcuts
$IELaunch = '\Microsoft\Internet Explorer\Quick Launch'
Remove-Item -Path "$([Environment]::GetFolderPath('Desktop'))\Microsoft Edge*.lnk" -Force -ErrorAction SilentlyContinue
Remove-Item -Path "$([Environment]::GetFolderPath('ApplicationData'))$IELaunch\Microsoft Edge*.lnk" -Force -ErrorAction SilentlyContinue
Remove-Item -Path "$($env:SystemRoot)\System32\config\systemprofile\AppData\Roaming$IELaunch\Microsoft Edge*.lnk" -Force -ErrorAction SilentlyContinue

## remove leftover tasks
Get-ScheduledTask -TaskName "MicrosoftEdge*" | Unregister-ScheduledTask -Confirm:$false -ErrorAction SilentlyContinue

## remove leftover files
"LocalApplicationData","ProgramFilesX86","ProgramFiles" | ForEach-Object {
    Remove-Item -Path "$([Environment]::GetFolderPath($_))\Microsoft\Edge*" -Force -Recurse -ErrorAction SilentlyContinue
}

Write-Host "Completed!"
