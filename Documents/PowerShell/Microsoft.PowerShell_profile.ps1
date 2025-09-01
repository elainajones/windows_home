# For reference
# $env:PATH="$env:PATH;C:\opt\vim-9.1.0\vim91\"
# $env:PATH="$env:PATH;C:\opt\MinGit-2.49.0\cmd\"
#
# Remove any pre-existing system alias so we can override it
Remove-Item Alias:wget -Force

function explorer {
    param (
        $Path = $PWD
    )
    explorer.exe $Path
}
function wget {
    param (
        [string]$Url,
        [string]$OutputPath = $(Split-Path -Leaf $Url)
    )
    if (Test-Path -PathType Container $OutputPath) {
        $Path = "${Path}\$(Split-Path -Leaf $Url)"
    } else {
        # Make sure parent path exists.
        New-Item -ItemType Directory -Path $(Split-Path -Parent $OutputPath) -Force > $null
    }

    Write-Host "Downloading $(Split-Path -Leaf $Url)"

    $ProgressPreference = 'SilentlyContinue'
    Invoke-WebRequest -Uri $Url -OutFile $OutputPath

    Write-Host "Saved to $OutputPath"
}
function find {
    param (
        [string]$Path = $PWD,
        [string]$Pattern
    )
    return Get-ChildItem -Path $Path -Recurse -ErrorAction SilentlyContinue -Include $Pattern
}

Set-Alias -Name c -Value clear
Set-Alias -Name e -Value explorer
Set-Alias -Name npp -Value "C:/Program Files/Notepad++/notepad++.exe"

# Set ctrl-d to behave as 'exit' just like in Bash
Set-PSReadLineKeyHandler -Chord 'Ctrl+d' -ScriptBlock {
    [Microsoft.PowerShell.PSConsoleReadLine]::RevertLine()
    [Microsoft.PowerShell.PSConsoleReadLine]::Insert('exit')
    [Microsoft.PowerShell.PSConsoleReadLine]::AcceptLine()
}
