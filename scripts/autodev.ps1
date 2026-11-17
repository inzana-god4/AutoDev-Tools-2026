[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet("deps", "apk", "device", "files", "rom")]
    [string]$Section,

    [Parameter(Mandatory = $true)]
    [string]$Command,

    [Parameter(ValueFromRemainingArguments = $true)]
    [Alias("Args")]
    [string[]]$RunnerArgs = @()
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

$ScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot = Resolve-Path (Join-Path $ScriptRoot "..")
$LegacyToolHome = "C:\Program Files (x86)\RBF Studio Inc\AutoDev Tools 2015"

function Get-ToolHomes {
    $homes = @()

    if ($env:AUTODEV_TOOL_HOME) {
        $homes += $env:AUTODEV_TOOL_HOME
    }

    $homes += (Join-Path $RepoRoot "tools")
    $homes += $LegacyToolHome

    $homes | Where-Object { $_ -and (Test-Path -LiteralPath $_) } | Select-Object -Unique
}

function Find-Tool {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$Candidates
    )

    foreach ($toolHome in Get-ToolHomes) {
        foreach ($candidate in $Candidates) {
            $path = Join-Path $toolHome $candidate
            if (Test-Path -LiteralPath $path) {
                return (Resolve-Path -LiteralPath $path).Path
            }
        }
    }

    foreach ($candidate in $Candidates) {
        $cmd = Get-Command $candidate -ErrorAction SilentlyContinue
        if ($cmd) {
            return $cmd.Source
        }
    }

    return $null
}

function Require-Tool {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name,

        [Parameter(Mandatory = $true)]
        [string[]]$Candidates
    )

    $tool = Find-Tool -Candidates $Candidates
    if (-not $tool) {
        throw "Missing tool '$Name'. Set AUTODEV_TOOL_HOME or place it under .\tools."
    }
    return $tool
}

function Require-Arg {
    param(
        [int]$Index,
        [string]$Name
    )

    if ($RunnerArgs.Count -le $Index -or [string]::IsNullOrWhiteSpace($RunnerArgs[$Index])) {
        throw "Missing argument: $Name"
    }

    return $RunnerArgs[$Index]
}

function Get-DefaultOutputPath {
    param(
        [string]$InputPath,
        [string]$Suffix
    )

    $directory = Split-Path -Parent $InputPath
    if (-not $directory) {
        $directory = "."
    }

    $name = [IO.Path]::GetFileNameWithoutExtension($InputPath)
    $extension = [IO.Path]::GetExtension($InputPath)
    return (Join-Path $directory "$name$Suffix$extension")
}

function Get-SafeName {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name
    )

    $safe = $Name
    foreach ($char in [IO.Path]::GetInvalidFileNameChars()) {
        $safe = $safe.Replace($char, "_")
    }
    if ([string]::IsNullOrWhiteSpace($safe)) {
        return "apk"
    }
    return $safe
}

function Invoke-External {
    param(
        [string]$Executable,
        [string[]]$Arguments
    )

    Write-Output "> $Executable $($Arguments -join ' ')"
    & $Executable @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "Command failed with exit code $LASTEXITCODE"
    }
}

function Invoke-JavaJar {
    param(
        [string]$Jar,
        [string[]]$Arguments
    )

    $java = Require-Tool -Name "java" -Candidates @("bin\java.exe", "java.exe")
    Invoke-External -Executable $java -Arguments (@("-jar", $Jar) + $Arguments)
}

function Show-DependencyScan {
    $checks = @(
        @{ Name = "adb"; Candidates = @("data\bin\adb.exe", "platform-tools\adb.exe", "adb.exe") },
        @{ Name = "fastboot"; Candidates = @("data\bin\fastboot.exe", "platform-tools\fastboot.exe", "fastboot.exe") },
        @{ Name = "apktool"; Candidates = @("data\modules\apktool.jar", "apktool.jar") },
        @{ Name = "aapt"; Candidates = @("data\modules\aapt.exe", "aapt.exe") },
        @{ Name = "signapk"; Candidates = @("data\modules\signapk.jar", "signapk.jar") },
        @{ Name = "zipalign"; Candidates = @("data\bin\zipalign.exe", "zipalign.exe") },
        @{ Name = "abe"; Candidates = @("data\modules\abe.jar", "abe.jar") },
        @{ Name = "sdat2img"; Candidates = @("data\bin\sdat2img.exe", "sdat2img.exe") },
        @{ Name = "rimg2sdat"; Candidates = @("data\bin\rimg2sdat.exe", "rimg2sdat.exe") },
        @{ Name = "java"; Candidates = @("bin\java.exe", "java.exe") }
    )

    Write-Output "AutoDev Tools 2026 dependency scan"
    Write-Output "Tool homes:"
    Get-ToolHomes | ForEach-Object { Write-Output "  - $_" }
    Write-Output ""

    $checks | ForEach-Object {
        $path = Find-Tool -Candidates $_.Candidates
        [PSCustomObject]@{
            Tool = $_.Name
            Status = if ($path) { "found" } else { "missing" }
            Path = if ($path) { $path } else { "" }
        }
    } | Format-Table -AutoSize
}

function Invoke-ApkCommand {
    switch ($Command) {
        "framework" {
            $framework = Require-Arg 0 "framework apk"
            $apktool = Require-Tool -Name "apktool" -Candidates @("data\modules\apktool.jar", "apktool.jar")
            Invoke-JavaJar -Jar $apktool -Arguments @("if", $framework)
        }
        "decompile" {
            $apk = Require-Arg 0 "apk path"
            if (-not (Test-Path -LiteralPath $apk)) {
                throw "APK not found: $apk"
            }
            $output = if ($RunnerArgs.Count -gt 1 -and $RunnerArgs[1]) {
                $RunnerArgs[1]
            } else {
                $name = Get-SafeName -Name ([IO.Path]::GetFileNameWithoutExtension($apk))
                Join-Path (Join-Path $RepoRoot "workspace") ($name + "_decompiled")
            }
            $parent = Split-Path -Parent $output
            if ($parent) {
                New-Item -ItemType Directory -Force -Path $parent | Out-Null
            }
            if (-not (Test-Path -LiteralPath $output)) {
                New-Item -ItemType Directory -Force -Path $output | Out-Null
            }
            $apktool = Require-Tool -Name "apktool" -Candidates @("data\modules\apktool.jar", "apktool.jar")
            Write-Output "Output folder: $output"
            Invoke-JavaJar -Jar $apktool -Arguments @("d", "-f", "-o", $output, $apk)
        }
        "recompile" {
            $project = Require-Arg 0 "decoded project path"
            $apktool = Require-Tool -Name "apktool" -Candidates @("data\modules\apktool.jar", "apktool.jar")
            Invoke-JavaJar -Jar $apktool -Arguments @("b", $project)
        }
        "sign" {
            $inputApk = Require-Arg 0 "apk path"
            $outputApk = if ($RunnerArgs.Count -gt 1 -and $RunnerArgs[1]) { $RunnerArgs[1] } else { Get-DefaultOutputPath $inputApk "_signed" }
            $signapk = Require-Tool -Name "signapk" -Candidates @("data\modules\signapk.jar", "signapk.jar")
            $certificate = Require-Tool -Name "certificate.pem" -Candidates @("data\essentials\certificate.pem", "certificate.pem")
            $key = Require-Tool -Name "key.pk8" -Candidates @("data\essentials\key.pk8", "key.pk8")
            Invoke-JavaJar -Jar $signapk -Arguments @($certificate, $key, $inputApk, $outputApk)
        }
        "zipalign" {
            $inputApk = Require-Arg 0 "apk path"
            $outputApk = if ($RunnerArgs.Count -gt 1 -and $RunnerArgs[1]) { $RunnerArgs[1] } else { Get-DefaultOutputPath $inputApk "_aligned" }
            $zipalign = Require-Tool -Name "zipalign" -Candidates @("data\bin\zipalign.exe", "zipalign.exe")
            Invoke-External -Executable $zipalign -Arguments @("-f", "-v", "4", $inputApk, $outputApk)
        }
        "install" {
            $apk = Require-Arg 0 "apk path"
            $adb = Require-Tool -Name "adb" -Candidates @("data\bin\adb.exe", "platform-tools\adb.exe", "adb.exe")
            Invoke-External -Executable $adb -Arguments @("install", "-r", $apk)
        }
        "uninstall" {
            $packageId = Require-Arg 0 "package id"
            $adb = Require-Tool -Name "adb" -Candidates @("data\bin\adb.exe", "platform-tools\adb.exe", "adb.exe")
            Invoke-External -Executable $adb -Arguments @("uninstall", $packageId)
        }
        default {
            throw "Unknown APK command: $Command"
        }
    }
}

function Invoke-DeviceCommand {
    $adb = Require-Tool -Name "adb" -Candidates @("data\bin\adb.exe", "platform-tools\adb.exe", "adb.exe")

    switch ($Command) {
        "list" { Invoke-External -Executable $adb -Arguments @("devices", "-l") }
        "check" { Invoke-External -Executable $adb -Arguments @("get-state") }
        "shell" { Invoke-External -Executable $adb -Arguments @("shell") }
        "reboot" { Invoke-External -Executable $adb -Arguments @("reboot") }
        "recovery" { Invoke-External -Executable $adb -Arguments @("reboot", "recovery") }
        "bootloader" { Invoke-External -Executable $adb -Arguments @("reboot", "bootloader") }
        "connect" {
            $target = Require-Arg 0 "host:port"
            Invoke-External -Executable $adb -Arguments @("connect", $target)
        }
        "disconnect" {
            $target = Require-Arg 0 "host:port"
            Invoke-External -Executable $adb -Arguments @("disconnect", $target)
        }
        "logcat" {
            Invoke-External -Executable $adb -Arguments @("logcat", "-d", "-t", "300")
        }
        "screenshot" {
            $output = if ($RunnerArgs.Count -gt 0 -and $RunnerArgs[0]) { $RunnerArgs[0] } else { Join-Path $RepoRoot "screenshot.png" }
            $devicePath = "/sdcard/autodev-reborn-screenshot.png"
            Invoke-External -Executable $adb -Arguments @("shell", "screencap", "-p", $devicePath)
            Invoke-External -Executable $adb -Arguments @("pull", $devicePath, $output)
            Invoke-External -Executable $adb -Arguments @("shell", "rm", $devicePath)
        }
        default {
            throw "Unknown device command: $Command"
        }
    }
}

function Invoke-FilesCommand {
    switch ($Command) {
        "hash" {
            $path = Require-Arg 0 "file path"
            Get-FileHash -LiteralPath $path -Algorithm MD5
            Get-FileHash -LiteralPath $path -Algorithm SHA1
            Get-FileHash -LiteralPath $path -Algorithm SHA256
        }
        "pull-documents" {
            $destination = Require-Arg 0 "local destination path"
            $adb = Require-Tool -Name "adb" -Candidates @("data\bin\adb.exe", "platform-tools\adb.exe", "adb.exe")
            Invoke-External -Executable $adb -Arguments @("pull", "/sdcard/Documents", $destination)
        }
        "push-download" {
            $source = Require-Arg 0 "local source path"
            $adb = Require-Tool -Name "adb" -Candidates @("data\bin\adb.exe", "platform-tools\adb.exe", "adb.exe")
            Invoke-External -Executable $adb -Arguments @("push", $source, "/sdcard/Download/")
        }
        default {
            throw "Unknown files command: $Command"
        }
    }
}

function Invoke-RomCommand {
    switch ($Command) {
        "list-apks" {
            $workspace = Require-Arg 0 "ROM workspace path"
            Get-ChildItem -LiteralPath $workspace -Recurse -Filter "*.apk" | Select-Object FullName, Length, LastWriteTime | Format-Table -AutoSize
        }
        "add-apk" {
            $apk = Require-Arg 0 "APK path"
            $workspace = Require-Arg 1 "ROM workspace path"
            $targetDir = Join-Path $workspace "system\app"
            New-Item -ItemType Directory -Force -Path $targetDir | Out-Null
            Copy-Item -LiteralPath $apk -Destination $targetDir -Force
            Write-Output "Added APK to $targetDir"
        }
        "bootanimation" {
            $bootanimation = Require-Arg 0 "bootanimation.zip path"
            $workspace = Require-Arg 1 "ROM workspace path"
            $targetDir = Join-Path $workspace "system\media"
            New-Item -ItemType Directory -Force -Path $targetDir | Out-Null
            Copy-Item -LiteralPath $bootanimation -Destination (Join-Path $targetDir "bootanimation.zip") -Force
            Write-Output "Updated bootanimation.zip"
        }
        "makezip" {
            $workspace = Require-Arg 0 "ROM workspace path"
            $outputZip = if ($RunnerArgs.Count -gt 1 -and $RunnerArgs[1]) { $RunnerArgs[1] } else { Join-Path $RepoRoot "rom-build.zip" }
            Compress-Archive -Path (Join-Path $workspace "*") -DestinationPath $outputZip -Force
            Write-Output "Created $outputZip"
        }
        default {
            throw "Unknown ROM command: $Command"
        }
    }
}

switch ($Section) {
    "deps" {
        if ($Command -ne "scan") {
            throw "Unknown deps command: $Command"
        }
        Show-DependencyScan
    }
    "apk" { Invoke-ApkCommand }
    "device" { Invoke-DeviceCommand }
    "files" { Invoke-FilesCommand }
    "rom" { Invoke-RomCommand }
}
