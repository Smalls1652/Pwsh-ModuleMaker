[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$ModuleName,
    [string]$Description,
    [string]$OutFolder,
    [string]$StandardConfig
)

begin {
    $OutFolder = (Get-Item -Path $OutFolder).FullName

    $ConfigData = (ConvertFrom-Json -InputObject (Get-Content -Path $StandardConfig -Raw))

    $ModuleManifestSplat = @{
        "Author" = $ConfigData.Author;
        "CompanyName" = $ConfigData.CompanyName;
        "Description" = $Description;
        "ModuleVersion" = (Get-Date -Format "yy.MM.dd");
        "RootModule" = "$($ModuleName).psm1"
        "Guid" = (New-Guid).Guid;
        "Copyright" = (Get-Date -Format "yyyy");
        "FunctionsToExport" = @();
        "AliasesToExport" = @();
        "CmdletsToExport" = @();
        "VariablesToExport" = @();
    }

    $ProjectConfig = @{
        "ModuleName" = $ModuleName
    }

    $FunctionsConfig = @{
        "Functions" = @()
    }
}

process {
    Write-Verbose "Creating project folder..."
    $ProjectFolder = New-Item -Path $OutFolder -Name $ModuleName -ItemType Directory

    Write-Verbose "Creating README.md file..."
    $ReadmeContents = "# $($ModuleName)`n`n$($Description)"
    $null = New-Item -Path $ProjectFolder -Name "README.md" -ItemType File -Value $ReadmeContents

    Write-Verbose "Creating module folder..."
    $ModuleFolder = New-Item -Path $ProjectFolder -Name $ModuleName -ItemType Directory
    $ProjectConfig.Add("ModulePath", (Join-Path -Path "." -ChildPath $ModuleName))

    Write-Verbose "Creating configs folder..."
    $ConfigFolder = New-Item -Path $ProjectFolder -Name "Configs" -ItemType Directory
    $ProjectConfig.Add("ConfigPath", (Join-Path -Path "." -ChildPath "Configs"))

    Write-Verbose "Creating ScriptFiles folder..."
    $null = New-Item -Path $ProjectFolder -Name "ScriptFiles" -ItemType Directory
    $ProjectConfig.Add("ScriptFilesPath", (Join-Path -Path "." -ChildPath "ScriptFiles"))

    Write-Verbose "Creating Tests folder..."
    $null = New-Item -Path $ProjectFolder -Name "Tests" -ItemType Directory
    $ProjectConfig.Add("TestsPath", (Join-Path -Path "./" -ChildPath "Tests"))

    Write-Verbose "Initializing module psm1 file in module folder..."
    $null = New-Item -Path $ModuleFolder -Name "$($ModuleName).psm1" -ItemType File

    $ModuleManifestSplat.Add("Path", (Join-Path -Path $ModuleName -ChildPath "$($ModuleName).psd1"))

    Write-Verbose "Initialzing project config files..."
    $ModuleManifestSplat | ConvertTo-Json -Depth 10 | Out-File -FilePath (Join-Path -Path $ConfigFolder.FullName -ChildPath "modulemanifest.json")
    $FunctionsConfig | ConvertTo-Json -Depth 10 | Out-File -FilePath (Join-Path -Path $ConfigFolder.FullName -ChildPath "functions.json")
    $ProjectConfig | ConvertTo-Json -Depth 10 | Out-File -FilePath (Join-Path -Path $ProjectFolder.FullName -ChildPath "project.json")

    Write-Verbose "Initializing module manifest..."
    Push-Location -Path $ProjectFolder
    New-ModuleManifest @ModuleManifestSplat
    Pop-Location

    Write-Verbose "Initialize project with git..."
    $GitOut = New-TemporaryFile
    Start-Process -FilePath "git" -ArgumentList "init" -WorkingDirectory $ProjectFolder -Wait -RedirectStandardOutput $GitOut
    Write-Verbose "Git Output: '$(Get-Content -Path $GitOut)'"
}

end {
    Remove-Item -Path $GitOut
    Write-Verbose "Done."
}