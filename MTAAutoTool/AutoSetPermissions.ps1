
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Создаем форму
$form = New-Object System.Windows.Forms.Form
$form.Text = "Права доступа к файлам"
$form.Size = New-Object System.Drawing.Size(500, 280)
$form.StartPosition = "CenterScreen"

# Метка и поле для пути
$pathLabel = New-Object System.Windows.Forms.Label
$pathLabel.Text = "Путь к папке:"
$pathLabel.Location = New-Object System.Drawing.Point(10, 20)
$pathLabel.Size = New-Object System.Drawing.Size(100, 20)
$form.Controls.Add($pathLabel)

$pathBox = New-Object System.Windows.Forms.TextBox
$pathBox.Location = New-Object System.Drawing.Point(120, 18)
$pathBox.Size = New-Object System.Drawing.Size(260, 20)
$form.Controls.Add($pathBox)

$browseButton = New-Object System.Windows.Forms.Button
$browseButton.Text = "Выбрать..."
$browseButton.Location = New-Object System.Drawing.Point(390, 16)
$browseButton.Size = New-Object System.Drawing.Size(80, 24)
$form.Controls.Add($browseButton)

$browseButton.Add_Click({
    $folderBrowser = New-Object System.Windows.Forms.FolderBrowserDialog
    if ($folderBrowser.ShowDialog() -eq "OK") {
        $pathBox.Text = $folderBrowser.SelectedPath
    }
})

# Поле для имени пользователя
$userLabel = New-Object System.Windows.Forms.Label
$userLabel.Text = "Имя пользователя:"
$userLabel.Location = New-Object System.Drawing.Point(10, 60)
$userLabel.Size = New-Object System.Drawing.Size(110, 20)
$form.Controls.Add($userLabel)

$userBox = New-Object System.Windows.Forms.TextBox
$userBox.Location = New-Object System.Drawing.Point(120, 58)
$userBox.Size = New-Object System.Drawing.Size(260, 20)
$form.Controls.Add($userBox)

# Кнопка запуска
$okButton = New-Object System.Windows.Forms.Button
$okButton.Text = "Применить"
$okButton.Location = New-Object System.Drawing.Point(190, 100)
$okButton.Size = New-Object System.Drawing.Size(100, 30)
$form.Controls.Add($okButton)

$okButton.Add_Click({
    $folderPath = $pathBox.Text.Trim()
    $username = $userBox.Text.Trim()

    # Экранируем спецсимволы в пути
    $safePath = [System.Management.Automation.WildcardPattern]::Escape($folderPath)

    if (-not (Test-Path $safePath)) {
        [System.Windows.Forms.MessageBox]::Show("Папка не найдена: `n$folderPath", "Ошибка", "OK", "Error")
        return
    }

    $files = Get-ChildItem -Path $folderPath -File -Recurse

    foreach ($file in $files) {
        try {
            $file.Attributes = $file.Attributes -bor [System.IO.FileAttributes]::ReadOnly
            $acl = Get-Acl $file.FullName

            $acl.Access | Where-Object { $_.IdentityReference.Value -eq $username } | ForEach-Object {
                $acl.RemoveAccessRuleAll($_)
            }

            $allowRule = New-Object System.Security.AccessControl.FileSystemAccessRule(
                $username, "FullControl", "Allow"
            )
            $acl.AddAccessRule($allowRule)

            $denyRule = New-Object System.Security.AccessControl.FileSystemAccessRule(
                $username, "Write", "Deny"
            )
            $acl.AddAccessRule($denyRule)

            Set-Acl -Path $file.FullName -AclObject $acl
        }
        catch {
            Write-Warning "Ошибка при обработке: $($file.FullName)"
        }
    }

    [System.Windows.Forms.MessageBox]::Show("Права успешно применены для $username!", "Готово", "OK", "Information")
})

$form.Topmost = $true
$form.Add_Shown({$form.Activate()})
[void]$form.ShowDialog()
