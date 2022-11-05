param 
(
    # Путь к папке с репозиторием
    [ValidateNotNullOrEmpty()]
    [Parameter(Mandatory = $true)]
    [string] $workingFolder,

    # Url до репы
    [ValidateNotNullOrEmpty()]
    [Parameter(Mandatory = $true)]
    [string] $repoAddress,

    # Пакеты для обновления
    [Parameter(Mandatory = $false)]
    [string[]] $includingPackages,

    # Префикс бранчи
    [Parameter(Mandatory = $false)]
    [string] $testBranchPrefix
)

. $PSScriptRoot/common_functions.ps1

$includingPackagesString = New-Object Collections.Generic.List[string]
if ($includingPackages)
{
    for ($i = 0; $i -lt $includingPackages.Count; $i++) {
        $item = $includingPackages[$i]
        $includingPackagesString.Add("-inc $item")
    }
}

$currentDate = Get-Date -Format dd_MM_yyyy
$testBranchName = "update_deps_$currentDate"

if($testBranchPrefix)
{
    $testBranchName = "$testBranchPrefix-$testBranchName"
}

$repoName = GetRepoName $repoAddress
$solutionFolder = Join-Path $workingFolder $repoName

## Скачиваем репу
Write-Host "Cloning $repoName project"
git -C $workingFolder clone $repoAddress
# Создаём ветку
git -C $solutionFolder checkout -b $testBranchName

# Проверяем, что есть ли обновления для компонентов
$packagesToUpdate = GetAvailablePackagesToUpdate $solutionFolder $includingPackages

if ($packagesToUpdate.Count -eq 0) {
    Write-Host "No updates needed!" -BackgroundColor White -ForegroundColor Cyan
    ## Убираемся
    Write-Host "Cleanup after $repoName project"
    Remove-Item $solutionFolder -Recurse -Force
    return
}

# Обновляем зависимости в Build.props
UpdatePackagesInFile $solutionFolder $packagesToUpdate

# Обновляем зависимости
dotnet outdated -vl:minor -u:auto -f $solutionFolder $includingPackages

# Чекаем что все Ок
dotnet test $solutionFolder
if ($LASTEXITCODE -ne 0) {
    Write-Host "Test failed!" -BackgroundColor White -ForegroundColor Red
    Write-Host "You have to magage it your own!" -BackgroundColor White -ForegroundColor Red
    return
}

# Коммитим и пушим
git -C $solutionFolder add .
git -C $solutionFolder commit -m "Packages updated!"
# Создаем merge request в гитлаб
# https://docs.gitlab.com/ee/user/project/push_options.html
git -C $solutionFolder push origin ("{0}:{1}" -f "HEAD", $testBranchName) -o merge_request.create -o merge_request.title="Packages updated"

## Убираемся
Write-Host "Cleanup after $repoName project"
Remove-Item $solutionFolder -Recurse -Force
