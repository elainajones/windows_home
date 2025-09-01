function Download-File {
    param (
        [string]$Url,
        [string]$OutputPath = $(Split-Path -Leaf $Url)
    )
    if (Test-Path -PathType Leaf $OutputPath) {
        $Path = "${Path}\$(Split-Path -Leaf $Url)"
    } else {
        # Make sure parent path exists.
        New-Item -ItemType Directory -Path $(Split-Path -Parent $OutputPath) -Force > $null
    } Write-Host "Downloading $(Split-Path -Leaf $Url)"
    $ProgressPreference = 'SilentlyContinue'
    Invoke-WebRequest -Uri $Url -OutFile $OutputPath

    Write-Host "Saved to $OutputPath"
}

function Get-LeafBase {
    param (
        [string]$Path
    )

    return [System.IO.Path]::GetFileNameWithoutExtension($Path)

}

function Find-Path {
    param (
        [string]$Path = $PWD,
        [string]$Pattern
    )
    return Get-ChildItem -Path $Path -Recurse -ErrorAction SilentlyContinue -Include $Pattern
}

function New-TemporaryDirectory {
    # Not $env:TEMP, see https://stackoverflow.com/a/946017
    $tmp = [System.IO.Path]::GetTempPath()
    $name = (New-Guid).ToString("N")
    New-Item -ItemType Directory -Path (Join-Path $tmp $name)
}

function Add-OpenSSH {
    foreach ($i in Get-WindowsCapability -Online | Where-Object Name -like 'OpenSSH*') {
        # Install the OpenSSH Server
        Add-WindowsCapability -Online -Name $i.name
    }

    # Start the sshd service
    Start-Service sshd

    # OPTIONAL but recommended:
    Set-Service -Name sshd -StartupType 'Automatic'

    # Confirm the Firewall rule is configured. It should be created automatically by setup. Run the following to verify
    if (!(Get-NetFirewallRule -Name "OpenSSH-Server-In-TCP" -ErrorAction SilentlyContinue | Select-Object Name, Enabled)) {
        Write-Output "Firewall Rule 'OpenSSH-Server-In-TCP' does not exist, creating it..."
        New-NetFirewallRule -Name 'OpenSSH-Server-In-TCP' -DisplayName 'OpenSSH Server (sshd)' -Enabled True -Direction Inbound -Protocol TCP -Action Allow -LocalPort 22
    } else {
        Write-Output "Firewall rule 'OpenSSH-Server-In-TCP' has been created and exists."
    }
}

function main {
    $savePath = "C:\opt"

    # Allow running scripts (this might need to be run before running this
    Set-ExecutionPolicy -ExecutionPolicy ByPass

    # Install and run SSH.
    Add-OpenSSH

    # Make sure profile exists.
    New-Item -ItemType Directory -Path $savePath -Force > $null
    if (-Not (Test-Path -PathType Leaf -Path $PROFILE)) {
        New-Item -ItemType Directory -Path $(Split-Path -Parent $PROFILE) -Force > $null
        New-Item -ItemType File -Path $PROFILE -Force > $null
    }

    $sources = @{
        "git.exe" = "https://github.com/git-for-windows/git/releases/download/v2.49.0.windows.1/MinGit-2.49.0-64-bit.zip"
        "vim.exe" = "https://github.com/vim/vim-win32-installer/releases/download/v9.1.1404/gvim_9.1.1404_x64_signed.zip"
    }

    foreach ($execName in $sources.Keys) {
        $url = $sources[$execName]
        $outputPath = "${savePath}\$(Get-LeafBase $url)\$(Split-Path -Leaf $url)"

        Download-File -Url $url -OutputPath $outputPath

        if (Test-Path -PathType Leaf -Path $outputPath) {
            # Extract download contents.
            Write-Host "Extracting contents to $(Split-Path -Parent $outputPath)"
            tar -xf $outputPath -C $(Split-Path -Parent $outputPath)
            # Find path to executable.
            $execPath = Find-Path -Path $(Split-Path -Parent $outputPath) -Pattern $execName

            if ($execPath.Length -gt 0) {
                Write-Host "Found path to $execName"
                # If more than 1 possible executable match is found, get
                # only the first one.
                $execPath = Split-Path -Parent $execPath[0].FullName

                # Append to active PATH variable.
                $env:Path = "$env:PATH;$execPath"

                # Format line to add executable to path.
                $newLine = '$env:PATH="$env:PATH;'
                $newLine += $execPath
                $newLine += '"'

                # Get existing profile content.
                $content = Get-Content $PROFILE
                # Prepend the path newline.
                $newContent = @($newLine, $content)

                # Write both newline and old content back to profile.
                $newContent | Set-Content $PROFILE
                Write-Host "Appended $execName to PATH"
            }
        }
    }
    Write-Host "Finished installing packages"

    $tempDir = New-TemporaryDirectory
    $url = "https://www.github.com/elainajones/windows_home.git"

    git clone --recurse-submodules -j4 $url $tempDir

    # We could iterate over the contents of $tempDir to copy everything,
    # but this is tricky to do without polluting $HOME. Instead, copy
    # only what we need on a case-by-case basis.
    #
    # Copy _vimrc and vimfiles (plugins, etc).
    Copy-Item -Recurse -Force -Path "${tempDir}\vimfiles" -Destination $HOME
    Copy-Item -Force -Path "${tempDir}\_vimrc" -Destination $HOME
    # Copy .gitconfig if not already present.
    if (-Not (Test-Path -PathType Leaf $HOME\.gitconfig)) {
        Copy-Item -Force -Path "${tempDir}\.gitconfig" -Destination $HOME
    }
    # Copy .git-credentials sample if not already present.
    if (-Not (Test-Path -PathType Leaf $HOME\.git-credentials)) {
        Copy-Item -Force -Path "${tempDir}\.git-credentials" -Destination $HOME
    }
    # Append to $PROFILE
    $path = Find-Path -Path $tempDir -Pattern "Microsoft.PowerShell_profile.ps1"
    if ($path.Length -gt 0) {
        Get-Content $path[0].Fullname | Add-Content $PROFILE
    }

    # Change the default SSH shell from CMD to PowerShell.
    $path = Get-Command powershell
    New-ItemProperty -Path "HKLM:\SOFTWARE\OpenSSH" -Name DefaultShell -Value $path.Source -PropertyType String -Force

    # Remove the stupid app execution alias for Python so it uses our
    # installation instead of trying to open the Microsoft Store.
    Remove-Item $env:USERPROFILE\AppData\Local\Microsoft\WindowsApps\python*.exe

    # Download installers to simplify setup.
    Download-File "https://www.python.org/ftp/python/3.13.7/python-3.13.7-amd64.exe" ~/Downloads

    # Cleanup temp files.
    Remove-Item -Recurse -Force -Path $tempDir > $null

    Write-Host "Finished copying configuration files"
}
main
