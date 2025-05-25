function Download-File {
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

# For reference
# function New-TemporaryDirectory {
#     # Not $env:TEMP, see https://stackoverflow.com/a/946017
#     $tmp = [System.IO.Path]::GetTempPath()
#     $name = (New-Guid).ToString("N")
#     New-Item -ItemType Directory -Path (Join-Path $tmp $name)
# }

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
}

main
