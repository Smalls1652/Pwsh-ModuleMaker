[CmdletBinding()]
param(
    [string]$ProjectPath = "./",
    [string]$ModuleVersion,
    [string]$Description,
    [string[]]$RequiredModules,
    [int]$Copyright
)

begin {
    $ProjectPathObj = Get-Item -Path $ProjectPath

    Push-Location -Path $ProjectPathObj -StackName "Original"

    Write-Verbose "Loading ModuleManifest config file..."
    $ModuleManifestData = ConvertFrom-Json -InputObject (Get-Content -Path (Join-Path -Path "Configs" -ChildPath "modulemanifest.json") -Raw)

    if (!($ModuleManifestData.RequiredModules)) {
        Add-Member -InputObject $ModuleManifestData -MemberType NoteProperty -Name "RequiredModules" -Value @()
    }
}

process {
    $ModuleManifestSplat = @{
        "Path" = $ModuleManifestData.Path;
        "RequiredModules" = $ModuleManifestData.RequiredModules
    }

    if ($ModuleVersion) {
        Write-Verbose "Changing ModuleVersion from '$($ModuleManifestData.ModuleVersion)' to '$($ModuleVersion)'."
        $ModuleManifestData.ModuleVersion = $ModuleVersion
        $ModuleManifestSplat.Add("ModuleVersion", $ModuleVersion)
    }

    if ($Description) {
        Write-Verbose "Changing ModuleVersion from '$($ModuleManifestData.ModuleVersion)' to '$($ModuleVersion)'."
        $ModuleManifestData.Description = $Description
        $ModuleManifestSplat.Add("Description", $Description)
    }

    if ($Copyright) {
        Write-Verbose "Changing ModuleVersion from '$($ModuleManifestData.ModuleVersion)' to '$($ModuleVersion)'."
        $ModuleManifestData.Copyright = $Copyright
        $ModuleManifestSplat.Add("Copyright", $Copyright)
    }

    if ($RequiredModules) {
        foreach ($Item in $RequiredModules) {
            if ($ModuleManifestData.RequiredModules -notcontains $Item) {
                Write-Verbose "Adding '$($Item)' to RequiredModules."
                $ModuleManifestData.RequiredModules += $Item
                $ModuleManifestSplat.RequiredModules += $Item
            }
        }
    }

    Write-Verbose "Writing data back to ModuleManifest config file..."
    $ModuleManifestData | ConvertTo-Json -Depth 10 | Out-File -FilePath (Join-Path -Path "Configs" -ChildPath "modulemanifest.json")

    Write-Verbose "Updating module manifest..."
    Update-ModuleManifest @ModuleManifestSplat
}

end {
    Pop-Location -StackName "Original"
    Write-Verbose "Done."
    return $ModuleManifestData
}