# Track in git
function explorer {
    explorer.exe .
}
Set-Alias -Name e -Value explorer
Set-Alias -Name c -Value clear
Set-Alias -Name npp -Value "C:/Program Files/Notepad++/notepad++.exe"

Set-PSReadLineKeyHandler -Chord 'Ctrl+d' -ScriptBlock {
    [Microsoft.PowerShell.PSConsoleReadLine]::RevertLine()
    [Microsoft.PowerShell.PSConsoleReadLine]::Insert('exit')
    [Microsoft.PowerShell.PSConsoleReadLine]::AcceptLine()
}
