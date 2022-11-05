function GetRepoName
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string] $repoUrl
    )
    
    return ($repoUrl -replace '^.*/(.*)\.git$','$1')
}

function GetAvailablePackagesToUpdateFromFile {
    [CmdletBinding()]
    param (
        [ValidateNotNullOrEmpty()]
        [Parameter(Mandatory = $true, Position = 0)]
        [string]$fileWithPackagesInfo
    )

    $packagesWithLatestVersion = @{}
    Get-Content $fileWithPackagesInfo -raw `
        | ConvertFrom-Json `
        | Select-Object -ExpandProperty Projects `
        | Select-Object -ExpandProperty TargetFrameworks `
        | Select-Object -ExpandProperty Dependencies `
        | ForEach-Object { $packagesWithLatestVersion[$_.Name] = $_.LatestVersion }

    return $packagesWithLatestVersion
}

function GetAvailablePackagesToUpdate {
    [CmdletBinding()]
    param (
        [ValidateNotNullOrEmpty()]
        [Parameter(Mandatory = $true, Position = 0)]
        [string]$pathToSolution,

        # Пакеты для обновления
        [Parameter(Mandatory = $false, Position = 1)]
        [string[]] $includingPackages
    )
    if ($includingPackages)
    {
        for ($i = 0; $i -lt $includingPackages.Count; $i++) {
            $item = $includingPackages[$i]
            $includingPackages[$i] = "-inc $item"
        }
    }

    $fileName = "$([guid]::NewGuid()).json"

    # Проверяем, что есть ли обновления для компонентов
    dotnet outdated -vl:minor -f $pathToSolution $includingPackages -o $fileName | Out-Null


    $result = GetAvailablePackagesToUpdateFromFile($fileName)

    Remove-Item $fileName
    return $result
}

function UpdatePackagesInFile {
    param (
        # Путь к папке с репозиторием
        [Parameter(Mandatory = $true, Position = 0)]
        [string] $solutionFolder,
        # Путь к папке с репозиторием
        [Parameter(Mandatory = $true, Position = 1)]
        [hashtable] $packagesToUpdate
    )
    
    $BuildPropsFileName = "Directory.Build.props"
    $pathToFile = Join-Path $solutionFolder $BuildPropsFileName
    $xml = [xml](Get-Content  $pathToFile)

    $matchingNodes = $xml.SelectNodes("//PackageReference") 
    foreach($node in $matchingNodes){
        if ($packagesToUpdate.ContainsKey($node."Include") -and $packagesToUpdate[$node."Include"] -gt $node."Version")
        {
            Write-Host "Package " $node."Include" $node."Version" "=>" $packagesToUpdate[$node."Include"]
            $node."Version" = $packagesToUpdate[$node."Include"]
        }
    }

    $xml.Save($pathToFile)
}
