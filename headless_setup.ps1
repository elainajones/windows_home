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

function main {
    $savePath = "C:\opt"

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

    # Cleanup.
    Remove-Item -Recurse -Force -Path $tempDir > $null

    Write-Host "Finished copying configuration files"
}
main
