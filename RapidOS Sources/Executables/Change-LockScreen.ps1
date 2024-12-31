# Taken from AtlasOS - https://github.com/Atlas-OS/Atlas/blob/main/src/playbook/Executables/AtlasModules/Scripts/Modules/Themes/Themes.psm1

function Set-LockscreenImage {
    param (
        [ValidateSet("light_lockscreen", "dark_lockscreen")]
        [string]$MyArgument
    )

    # Determine the path based on the MyArgument value
    $Path = if ($MyArgument -eq "light_lockscreen") {
        "$env:WinDir\RapidScripts\lockscreen-rapid-light.png"
    } else {
        "$env:WinDir\RapidScripts\lockscreen-rapid-dark.png"
    }

    if (!(Test-Path $Path)) {
        throw "Path ('$Path') for lockscreen not found."
    }

    $newImagePath = [System.IO.Path]::GetTempPath() + (New-Guid).Guid + [System.IO.Path]::GetExtension($Path)
    Copy-Item $Path $newImagePath

    # setup WinRT namespaces
    Add-Type -AssemblyName System.Runtime.WindowsRuntime
    [Windows.System.UserProfile.LockScreen, Windows.System.UserProfile, ContentType = WindowsRuntime] | Out-Null

    # setup async
    $asTaskGeneric = ([System.WindowsRuntimeSystemExtensions].GetMethods() | ? {
        $_.Name -eq 'AsTask' -and
        $_.GetParameters().Count -eq 1 -and
        $_.GetParameters()[0].ParameterType.Name -eq 'IAsyncOperation`1'
    })[0]
    
    Function Await($WinRtTask, $ResultType) {
        $asTask = $asTaskGeneric.MakeGenericMethod($ResultType)
        $netTask = $asTask.Invoke($null, @($WinRtTask))
        $netTask.Wait(-1) | Out-Null
        $netTask.Result
    }
    
    Function AwaitAction($WinRtAction) {
        $asTask = ([System.WindowsRuntimeSystemExtensions].GetMethods() | ? { $_.Name -eq 'AsTask' -and $_.GetParameters().Count -eq 1 -and !$_.IsGenericMethod })[0]
        $netTask = $asTask.Invoke($null, @($WinRtAction))
        $netTask.Wait(-1) | Out-Null
    }

    # make image object
    [Windows.Storage.StorageFile, Windows.Storage, ContentType = WindowsRuntime] | Out-Null
    $image = Await ([Windows.Storage.StorageFile]::GetFileFromPathAsync($newImagePath)) ([Windows.Storage.StorageFile])
    
    # execute
    AwaitAction ([Windows.System.UserProfile.LockScreen]::SetImageFileAsync($image))
    
    # cleanup
    Remove-Item $newImagePath
}

Set-LockscreenImage