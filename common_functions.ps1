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


Function Test-CommandExists {
    Param (
        # Имя команды
        [Parameter(Mandatory = $true, Position = 0)]
        [string]$command
    )
    $oldPreference = $ErrorActionPreference
    $ErrorActionPreference = ‘stop’
    try 
    {
        if (Get-Command $command)
        {
            return $true;
        }
    }
    Catch
    {
        return $false
    }
    Finally
    {
        $ErrorActionPreference=$oldPreference
    }
}

function UpdateOrInstallTools {
    Param (
        # номер требуемой версии для dotnet-outdated.exe
        [Parameter(Mandatory = $false, Position = 0)]
        [string]$requiredVersion = "4.3.0"
    )

    if (Test-CommandExists "dotnet-outdated.exe")
    {
        $version = (Get-Command dotnet-outdated.exe).Version.ToString();
        if ($version -ge $requiredVersion)
        {
            return;
        }

        Write-Information "The minimum dotnet-outdated-tool should be greater oe equal $requiredVersion"
        Write-Information "Uninstall current version"
        dotnet tool uninstall --global dotnet-outdated-tool
    }

    Write-Information "Install $requiredVersion version"
    dotnet tool install --global --version $requiredVersion dotnet-outdated-tool
}