param 
(
    # Путь к папке с репозиторием
    [Parameter(Mandatory = $true, Position = 0)]
    [string] $workingFolder,
    # Имя тестовой ветки
    [Parameter(Mandatory = $true, Position = 1)]
    [string] $testBranchName
)

$targetBranch = "master"

# Проверяем, что есть ли обновления для компонентов
dotnet outdated -t -vl:minor -f $workingFolder

if ($LASTEXITCODE -eq 0) {
    Write-Host "No updates needed!" -BackgroundColor White -ForegroundColor Green
    return
}

# Текущая ветка, в которой находимся
$oldBranch = git -C $workingFolder branch --show-current
$currentCommit = git -C $workingFolder rev-parse HEAD

# Переключаем папку на $targetBranch
git -C $workingFolder switch $targetBranch
# Подтягиваем изменения
git -C $workingFolder pull origin $targetBranch

# Создаём ветку
git -C $workingFolder branch $testBranchName
git -C $workingFolder switch $testBranchName

# Обновляем зависимости
dotnet outdated -t -vl:minor -u:auto $workingFolder

# Чекаем что все Ок
dotnet test $workingFolder
if ($LASTEXITCODE -ne 0) {
    Write-Host "Test failed!" -BackgroundColor White -ForegroundColor Red
    return
}

# Коммитим и пушим
git -C $workingFolder add .
git -C $workingFolder commit -m "Packages updated!"
git -C $workingFolder checkout -b $testBranchName
# Создаем merge request в гитлаб
# https://docs.gitlab.com/ee/user/project/push_options.html
git -C $workingFolder push origin ("{0}:{1}" -f "HEAD", $testBranchName) -o merge_request.create -o merge_request.title="Packages updated"

# Возвращаемся на старую ветку
git -C $workingFolder switch $oldBranch
git -C $workingFolder revert $currentCommit -n
git -C $workingFolder commit -m ("Revert to " -f $currentCommit)

 