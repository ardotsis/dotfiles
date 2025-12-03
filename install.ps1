Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$DotfilesRepoDir = $PSScriptRoot

function Test-Administrator {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object -TypeName Security.Principal.WindowsPrincipal($currentUser)
    $isAdmin = $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    return $isAdmin
}

function Set-VSCodeSymlink([string] $SourceDir) {
    $repoConfigDir = Join-Path -Path $SourceDir -ChildPath "\dotfiles\common\.config\Code\User"
    $winConfigDir = "$Env:APPDATA\Code\User"

    $items = @(
        "settings.json",
        "keybindings.json",
        "snippets"
    )

    foreach ($item in $items) {
        $source = Join-Path -Path $repoConfigDir -ChildPath $item
        $destination = Join-Path -Path $winConfigDir -ChildPath $item

        if (Test-Path -Path $destination) {
            Remove-Item -Path $destination -Recurse -Force
        }

        Write-Debug "Linking $destination -> $source"
        New-Item -ItemType SymbolicLink -Path $destination -Target $source | Out-Null
    }
}

function main() {
    if (-not (Test-Administrator)) {
        Write-Output "Not running as Administrator. Restarting..."
        $scriptPath = $MyInvocation.MyCommand.Definition
        Start-Process -FilePath "powershell.exe" -ArgumentList "-ExecutionPolicy Bypass -File `"$scriptPath`"" -Verb RunAs
        exit 0
    }

    Set-VSCodeSymlink -SourceDir $DotfilesRepoDir
}

main
