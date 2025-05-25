$env:PATH="$env:PATH;C:\opt\vim-9.1.0\vim91\"
$env:PATH="$env:PATH;C:\opt\MinGit-2.49.0\cmd\"
Remove-Item Alias:wget -Force

function explorer {
    explorer.exe .
}
function wget {
    param (
        $url
    )
    $ProgressPreference = 'SilentlyContinue'
    Invoke-WebRequest -Uri "$url" -OutFile "$(split-path \"$url\" -leaf)"
    Write-Host "Saved to $(split-path \"$url\" -leaf)"
}

Set-Alias -Name c -Value clear
Set-Alias -Name e -Value explorer
Set-Alias -Name npp -Value "C:/Program Files/Notepad++/notepad++.exe"

Set-PSReadLineKeyHandler -Chord 'Ctrl+d' -ScriptBlock {
    [Microsoft.PowerShell.PSConsoleReadLine]::RevertLine()
    [Microsoft.PowerShell.PSConsoleReadLine]::Insert('exit')
    [Microsoft.PowerShell.PSConsoleReadLine]::AcceptLine()
}
