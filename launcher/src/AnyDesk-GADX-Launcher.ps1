Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

if ($PSScriptRoot) {
    $baseDir = $PSScriptRoot
}
else {
    $baseDir = Split-Path -Parent $MyInvocation.MyCommand.Path
}
$csvPath = Join-Path $baseDir "maquinas.csv"

$preferredAnyDeskExeNames = @(
    "anydesk-GADX.exe",
    "AnyDesk-GADX.exe",
    "anyudesk-GADX.exe",
    "Anyudesk-GADX.exe"
)

function Find-AnyDeskPath {
    $clientDir = Join-Path $baseDir "Client"

    if (!(Test-Path -LiteralPath $clientDir)) {
        return $null
    }

    foreach ($exeName in $preferredAnyDeskExeNames) {
        $path = Join-Path $clientDir $exeName

        if (Test-Path -LiteralPath $path) {
            return [System.IO.Path]::GetFullPath($path)
        }
    }

    return $null
}

function Get-DedicatedAnyDeskProcesses($anydeskExe) {
    if ([string]::IsNullOrWhiteSpace($anydeskExe) -or !(Test-Path -LiteralPath $anydeskExe)) {
        return @()
    }

    # O escopo e o diretorio Client do launcher. Nunca procura processos em
    # Program Files, AppData ou qualquer outra instalacao do AnyDesk.
    $dedicatedClientDir = [System.IO.Path]::GetFullPath((Split-Path -Parent $anydeskExe)).TrimEnd('\') + '\'

    try {
        $processes = Get-CimInstance -ClassName Win32_Process -Filter "Name LIKE 'AnyDesk%.exe'" -ErrorAction Stop |
            Where-Object {
                if ([string]::IsNullOrWhiteSpace($_.ExecutablePath)) {
                    $false
                }
                else {
                    try {
                        $processPath = [System.IO.Path]::GetFullPath($_.ExecutablePath)
                        $processPath.StartsWith($dedicatedClientDir, [System.StringComparison]::OrdinalIgnoreCase)
                    }
                    catch {
                        $false
                    }
                }
            }

        return @($processes)
    }
    catch {
        throw "Nao foi possivel verificar a instancia dedicada do AnyDesk: $($_.Exception.Message)"
    }
}

function Wait-DedicatedAnyDeskExit($anydeskExe, $timeoutSeconds) {
    $deadline = (Get-Date).AddSeconds($timeoutSeconds)

    do {
        if (@(Get-DedicatedAnyDeskProcesses $anydeskExe).Count -eq 0) {
            return $true
        }

        Start-Sleep -Milliseconds 250
    } while ((Get-Date) -lt $deadline)

    return $false
}

function Close-DedicatedAnyDeskSession($anydeskExe) {
    $processes = @(Get-DedicatedAnyDeskProcesses $anydeskExe)

    if ($processes.Count -eq 0) {
        return
    }

    $status.Text = "Encerrando a sessao anterior do cliente GADX..."
    [System.Windows.Forms.Application]::DoEvents()

    foreach ($processInfo in $processes) {
        try {
            $process = Get-Process -Id $processInfo.ProcessId -ErrorAction Stop

            if ($process.MainWindowHandle -ne [IntPtr]::Zero) {
                $null = $process.CloseMainWindow()
            }
        }
        catch {
            # O processo pode ter terminado entre a consulta e o fechamento.
        }
    }

    if (Wait-DedicatedAnyDeskExit $anydeskExe 8) {
        return
    }

    # Se a interface nao responder, encerra somente os processos que ainda
    # pertencem ao diretorio Client deste launcher dedicado.
    foreach ($processInfo in @(Get-DedicatedAnyDeskProcesses $anydeskExe)) {
        try {
            Stop-Process -Id $processInfo.ProcessId -Force -ErrorAction Stop
        }
        catch {
            throw "Nao foi possivel encerrar a instancia dedicada anterior: $($_.Exception.Message)"
        }
    }

    if (!(Wait-DedicatedAnyDeskExit $anydeskExe 5)) {
        throw "A instancia dedicada anterior nao terminou. Nenhuma outra instalacao do AnyDesk foi alterada."
    }
}

function Show-Error($message) {
    [System.Windows.Forms.MessageBox]::Show(
        $message,
        "AnyDesk Infra Launcher",
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Error
    ) | Out-Null
}

function Show-Info($message) {
    [System.Windows.Forms.MessageBox]::Show(
        $message,
        "AnyDesk Infra Launcher",
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Information
    ) | Out-Null
}

function Open-AnyDeskWithOptionalPassword($anydeskExe, $address, $password) {
    if ([string]::IsNullOrWhiteSpace($address)) {
        throw "ID/Alias do AnyDesk vazio no CSV."
    }

    $cleanAddress = $address.Trim()
    Close-DedicatedAnyDeskSession $anydeskExe

    if (![string]::IsNullOrWhiteSpace($password)) {
        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName = $anydeskExe
        $psi.Arguments = "$cleanAddress --with-password"
        $psi.UseShellExecute = $false
        $psi.RedirectStandardInput = $true
        $psi.CreateNoWindow = $true

        $proc = [System.Diagnostics.Process]::Start($psi)
        $proc.StandardInput.WriteLine($password)
        $proc.StandardInput.Close()
        return "senha"
    }
    else {
        Start-Process -FilePath $anydeskExe -ArgumentList $cleanAddress
        return "manual"
    }
}

function New-Color($r, $g, $b) {
    return [System.Drawing.Color]::FromArgb($r, $g, $b)
}

function Get-SiteColor($index) {
    $palette = @(
        (New-Color 37 99 235),    # azul
        (New-Color 5 150 105),    # verde
        (New-Color 124 58 237),   # roxo
        (New-Color 217 119 6),    # amarelo/laranja
        (New-Color 220 38 38),    # vermelho
        (New-Color 8 145 178),    # cyan
        (New-Color 79 70 229),    # indigo
        (New-Color 101 163 13)    # oliva
    )
    return $palette[$index % $palette.Count]
}

function Add-CardShadowBorder($panel) {
    $panel.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
}

if (!(Test-Path $csvPath)) {
    Show-Error "Arquivo maquinas.csv nao encontrado na pasta do launcher."
    exit
}

try {
    $global:maquinas = Import-Csv -Path $csvPath -Encoding UTF8
}
catch {
    Show-Error "Erro ao ler maquinas.csv: $($_.Exception.Message)"
    exit
}

if (!$global:maquinas -or $global:maquinas.Count -eq 0) {
    Show-Error "O arquivo maquinas.csv esta vazio."
    exit
}

$global:anydeskPath = Find-AnyDeskPath

# Fontes
$fontHeader = New-Object System.Drawing.Font("Segoe UI", 18, [System.Drawing.FontStyle]::Bold)
$fontSub = New-Object System.Drawing.Font("Segoe UI", 9)
$fontSmall = New-Object System.Drawing.Font("Segoe UI", 8)
$fontTab = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
$fontCardTitle = New-Object System.Drawing.Font("Segoe UI", 12, [System.Drawing.FontStyle]::Bold)
$fontCardText = New-Object System.Drawing.Font("Segoe UI", 9)
$fontCardMono = New-Object System.Drawing.Font("Consolas", 10, [System.Drawing.FontStyle]::Bold)
$fontButton = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)

# Form principal
$form = New-Object System.Windows.Forms.Form
$form.Text = "Acesso AnyDesk - Infraestrutura v2.6"
$form.Size = New-Object System.Drawing.Size(1040, 700)
$form.StartPosition = "CenterScreen"
$form.MinimumSize = New-Object System.Drawing.Size(900, 580)
$form.BackColor = New-Color 241 245 249

# Header
$headerPanel = New-Object System.Windows.Forms.Panel
$headerPanel.Height = 122
$headerPanel.Dock = "Top"
$headerPanel.BackColor = New-Color 15 23 42

$titleLabel = New-Object System.Windows.Forms.Label
$titleLabel.Text = "Acesso AnyDesk"
$titleLabel.ForeColor = [System.Drawing.Color]::White
$titleLabel.Font = $fontHeader
$titleLabel.AutoSize = $false
$titleLabel.Location = New-Object System.Drawing.Point(24, 12)
$titleLabel.Size = New-Object System.Drawing.Size(420, 34)
$titleLabel.TextAlign = "MiddleLeft"

$subtitleLabel = New-Object System.Windows.Forms.Label
$subtitleLabel.Text = "Infraestrutura interna - estações organizadas por site"
$subtitleLabel.ForeColor = New-Color 203 213 225
$subtitleLabel.Font = $fontSub
$subtitleLabel.AutoSize = $false
$subtitleLabel.Location = New-Object System.Drawing.Point(27, 48)
$subtitleLabel.Size = New-Object System.Drawing.Size(520, 22)
$subtitleLabel.TextAlign = "MiddleLeft"

$pathLabel = New-Object System.Windows.Forms.Label
if ($global:anydeskPath) {
    $pathLabel.Text = "Cliente AnyDesk GADX encontrado: $global:anydeskPath"
    $pathLabel.ForeColor = New-Color 187 247 208
} else {
    $pathLabel.Text = "Cliente GADX nao encontrado. Coloque anydesk-GADX.exe ou anyudesk-GADX.exe nesta mesma pasta."
    $pathLabel.ForeColor = New-Color 254 202 202
}
$pathLabel.Font = $fontSmall
$pathLabel.AutoSize = $false
$pathLabel.Location = New-Object System.Drawing.Point(27, 72)
$pathLabel.Size = New-Object System.Drawing.Size(760, 20)
$pathLabel.TextAlign = "MiddleLeft"

$warningLabel = New-Object System.Windows.Forms.Label
$warningLabel.Text = "Modo com senha no CSV: use apenas em computador confiavel e protegido."
$warningLabel.ForeColor = New-Color 253 230 138
$warningLabel.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
$warningLabel.AutoSize = $false
$warningLabel.Location = New-Object System.Drawing.Point(27, 94)
$warningLabel.Size = New-Object System.Drawing.Size(760, 20)
$warningLabel.TextAlign = "MiddleLeft"

# Botoes topo
$btnEditCsv = New-Object System.Windows.Forms.Button
$btnEditCsv.Text = "Editar CSV"
$btnEditCsv.Width = 116
$btnEditCsv.Height = 32
$btnEditCsv.Anchor = "Top,Right"
$btnEditCsv.Location = New-Object System.Drawing.Point(772, 18)
$btnEditCsv.Font = $fontButton
$btnEditCsv.BackColor = New-Color 30 64 175
$btnEditCsv.ForeColor = [System.Drawing.Color]::White
$btnEditCsv.FlatStyle = "Flat"
$btnEditCsv.FlatAppearance.BorderSize = 0
$btnEditCsv.Add_Click({
    if (Test-Path $csvPath) {
        Start-Process -FilePath "notepad.exe" -ArgumentList "`"$csvPath`""
    }
})

$btnReload = New-Object System.Windows.Forms.Button
$btnReload.Text = "Recarregar"
$btnReload.Width = 116
$btnReload.Height = 32
$btnReload.Anchor = "Top,Right"
$btnReload.Location = New-Object System.Drawing.Point(900, 18)
$btnReload.Font = $fontButton
$btnReload.BackColor = New-Color 51 65 85
$btnReload.ForeColor = [System.Drawing.Color]::White
$btnReload.FlatStyle = "Flat"
$btnReload.FlatAppearance.BorderSize = 0
$btnReload.Add_Click({
    $launcherVbs = Join-Path $baseDir "Abrir-AnyDesk-GADX.vbs"

    if (Test-Path -LiteralPath $launcherVbs) {
        Start-Process -FilePath "wscript.exe" -ArgumentList "`"$launcherVbs`"" -WorkingDirectory $baseDir
    }
    else {
        Show-Error "Nao encontrei o inicializador do launcher:`r`n$launcherVbs"
        return
    }

    $form.Close()
})

$btnFolder = New-Object System.Windows.Forms.Button
$btnFolder.Text = "Abrir Pasta"
$btnFolder.Width = 116
$btnFolder.Height = 30
$btnFolder.Anchor = "Top,Right"
$btnFolder.Location = New-Object System.Drawing.Point(772, 58)
$btnFolder.Font = $fontButton
$btnFolder.BackColor = New-Color 71 85 105
$btnFolder.ForeColor = [System.Drawing.Color]::White
$btnFolder.FlatStyle = "Flat"
$btnFolder.FlatAppearance.BorderSize = 0
$btnFolder.Add_Click({
    Start-Process -FilePath "explorer.exe" -ArgumentList "`"$baseDir`""
})

$btnAbout = New-Object System.Windows.Forms.Button
$btnAbout.Text = "Info"
$btnAbout.Width = 116
$btnAbout.Height = 30
$btnAbout.Anchor = "Top,Right"
$btnAbout.Location = New-Object System.Drawing.Point(900, 58)
$btnAbout.Font = $fontButton
$btnAbout.BackColor = New-Color 71 85 105
$btnAbout.ForeColor = [System.Drawing.Color]::White
$btnAbout.FlatStyle = "Flat"
$btnAbout.FlatAppearance.BorderSize = 0
$btnAbout.Add_Click({
    Show-Info "AnyDesk Infra Launcher`r`n`r`n- Le maquinas.csv`r`n- Organiza por site`r`n- Usa senha do CSV se preenchida`r`n- Usa o cliente anyudesk-GADX.exe da mesma pasta`r`n- Se senha estiver vazia, abre AnyDesk e pede manualmente`r`n`r`nRecomendado: BitLocker + ACL no AnyDesk remoto."
})

$headerPanel.Controls.Add($titleLabel)
$headerPanel.Controls.Add($subtitleLabel)
$headerPanel.Controls.Add($pathLabel)
$headerPanel.Controls.Add($warningLabel)
$headerPanel.Controls.Add($btnEditCsv)
$headerPanel.Controls.Add($btnReload)
$headerPanel.Controls.Add($btnFolder)
$headerPanel.Controls.Add($btnAbout)

# Barra de busca / resumo
$searchPanel = New-Object System.Windows.Forms.Panel
$searchPanel.Height = 58
$searchPanel.Dock = "Top"
$searchPanel.BackColor = New-Color 226 232 240

$searchLabel = New-Object System.Windows.Forms.Label
$searchLabel.Text = "Buscar:"
$searchLabel.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
$searchLabel.ForeColor = New-Color 30 41 59
$searchLabel.Location = New-Object System.Drawing.Point(24, 17)
$searchLabel.Size = New-Object System.Drawing.Size(64, 24)
$searchLabel.TextAlign = "MiddleLeft"

$searchBox = New-Object System.Windows.Forms.TextBox
$searchBox.Font = New-Object System.Drawing.Font("Segoe UI", 11)
$searchBox.Location = New-Object System.Drawing.Point(92, 15)
$searchBox.Width = 340
$searchBox.Height = 28

$totalLabel = New-Object System.Windows.Forms.Label
$total = @($global:maquinas).Count
$sites = @($global:maquinas | Group-Object site).Count
$totalLabel.Text = "$total maquinas cadastradas em $sites sites"
$totalLabel.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
$totalLabel.ForeColor = New-Color 51 65 85
$totalLabel.AutoSize = $false
$totalLabel.Location = New-Object System.Drawing.Point(548, 16)
$totalLabel.Size = New-Object System.Drawing.Size(440, 24)
$totalLabel.TextAlign = "MiddleLeft"

$btnClearSearch = New-Object System.Windows.Forms.Button
$btnClearSearch.Text = "Limpar"
$btnClearSearch.Width = 86
$btnClearSearch.Height = 28
$btnClearSearch.Location = New-Object System.Drawing.Point(438, 14)
$btnClearSearch.Font = $fontButton
$btnClearSearch.BackColor = [System.Drawing.Color]::White
$btnClearSearch.ForeColor = New-Color 30 41 59
$btnClearSearch.FlatStyle = "Flat"
$btnClearSearch.FlatAppearance.BorderColor = New-Color 203 213 225
$btnClearSearch.Add_Click({
    $searchBox.Text = ""
})

$searchPanel.Controls.Add($searchLabel)
$searchPanel.Controls.Add($searchBox)
$searchPanel.Controls.Add($btnClearSearch)
$searchPanel.Controls.Add($totalLabel)

function Show-DataMaintenanceGuidance {
    $message = "A manutencao de dados nao e executada automaticamente.`r`n`r`n" +
        "Os dados em AppData/ProgramData podem ser compartilhados com outras instalacoes do AnyDesk e sua limpeza pode remover identidade, configuracoes e historico.`r`n`r`n" +
        "Para uma manutencao controlada, encerre todas as sessoes, identifique a pasta que pertence ao cliente dedicado e confirme um backup antes de qualquer remocao."

    [System.Windows.Forms.MessageBox]::Show(
        $message,
        "Manutencao de dados do AnyDesk",
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Warning
    ) | Out-Null

    $status.Text = "Nenhum dado do AnyDesk foi alterado."
}

function Create-DesktopShortcut {
    $vbsPath = Join-Path $baseDir "Abrir-AnyDesk-GADX.vbs"
    $iconPath = Join-Path $baseDir "AnyDesk-GADX-Launcher.ico"
    $shortcutName = "Anydesk GADX.lnk"
    $desktopPath = [Environment]::GetFolderPath("Desktop")
    $shortcutPath = Join-Path $desktopPath $shortcutName

    if (!(Test-Path -LiteralPath $vbsPath)) {
        Show-Error "Nao encontrei o arquivo:`r`n$vbsPath`r`n`r`nO atalho precisa apontar para Abrir-AnyDesk-sem-console.vbs."
        return
    }

    try {
        $shell = New-Object -ComObject WScript.Shell
        $shortcut = $shell.CreateShortcut($shortcutPath)
        $shortcut.TargetPath = $vbsPath
        $shortcut.WorkingDirectory = $baseDir
        $shortcut.Description = "Acesso AnyDesk GADX"

        if (Test-Path -LiteralPath $iconPath) {
            $shortcut.IconLocation = "$iconPath,0"
        }
        else {
            $clientIcon = Find-AnyDeskPath
            if ($clientIcon) {
                $shortcut.IconLocation = "$clientIcon,0"
            }
        }

        $shortcut.Save()

        if (Test-Path -LiteralPath $shortcutPath) {
            Show-Info "Atalho criado na Area de Trabalho:`r`n$shortcutPath"
            $status.Text = "Atalho criado na Area de Trabalho: Anydesk GADX"
        }
        else {
            Show-Error "O comando foi executado, mas o atalho nao foi encontrado na Area de Trabalho."
        }
    }
    catch {
        Show-Error "Erro ao criar o atalho:`r`n$($_.Exception.Message)"
    }
}

# Rodape / Status
$bottomPanel = New-Object System.Windows.Forms.Panel
$bottomPanel.Height = 42
$bottomPanel.Dock = "Bottom"
$bottomPanel.BackColor = New-Color 226 232 240

$status = New-Object System.Windows.Forms.Label
$status.Text = "Selecione uma maquina para abrir no AnyDesk."
$status.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$status.AutoSize = $false
$status.Location = New-Object System.Drawing.Point(270, 0)
$status.Size = New-Object System.Drawing.Size(430, 42)
$status.Anchor = "Left,Top,Right"
$status.TextAlign = "MiddleCenter"
$status.BackColor = New-Color 226 232 240
$status.ForeColor = New-Color 30 41 59

$btnCreateShortcut = New-Object System.Windows.Forms.Button
$btnCreateShortcut.Text = "Criar icone na Area de Trabalho"
$btnCreateShortcut.Width = 235
$btnCreateShortcut.Height = 28
$btnCreateShortcut.Anchor = "Top,Right"
$btnCreateShortcut.Location = New-Object System.Drawing.Point(770, 7)
$btnCreateShortcut.Font = New-Object System.Drawing.Font("Segoe UI", 8, [System.Drawing.FontStyle]::Bold)
$btnCreateShortcut.BackColor = [System.Drawing.Color]::White
$btnCreateShortcut.ForeColor = New-Color 30 41 59
$btnCreateShortcut.FlatStyle = "Flat"
$btnCreateShortcut.FlatAppearance.BorderColor = New-Color 203 213 225
$btnCreateShortcut.Add_Click({
    Create-DesktopShortcut
})


$btnCleanAppData = New-Object System.Windows.Forms.Button
$btnCleanAppData.Text = "Manutencao de dados"
$btnCleanAppData.Width = 235
$btnCleanAppData.Height = 28
$btnCleanAppData.Anchor = "Top,Left"
$btnCleanAppData.Location = New-Object System.Drawing.Point(18, 7)
$btnCleanAppData.Font = New-Object System.Drawing.Font("Segoe UI", 8, [System.Drawing.FontStyle]::Bold)
$btnCleanAppData.BackColor = [System.Drawing.Color]::White
$btnCleanAppData.ForeColor = New-Color 153 27 27
$btnCleanAppData.FlatStyle = "Flat"
$btnCleanAppData.FlatAppearance.BorderColor = New-Color 248 113 113
$btnCleanAppData.Add_Click({
    Show-DataMaintenanceGuidance
})

$bottomPanel.Add_Resize({
    $btnCreateShortcut.Left = $bottomPanel.ClientSize.Width - $btnCreateShortcut.Width - 18
    $status.Left = $btnCleanAppData.Right + 12
    $status.Width = $btnCreateShortcut.Left - $status.Left - 12

    if ($status.Width -lt 120) {
        $status.Width = 120
    }
})

$bottomPanel.Controls.Add($btnCleanAppData)
$bottomPanel.Controls.Add($status)
$bottomPanel.Controls.Add($btnCreateShortcut)

# Tabs
$tabs = New-Object System.Windows.Forms.TabControl
$tabs.Dock = "Fill"
$tabs.Font = $fontTab
$tabs.Padding = New-Object System.Drawing.Point(22, 10)
$tabs.SizeMode = [System.Windows.Forms.TabSizeMode]::Fixed
$tabs.ItemSize = New-Object System.Drawing.Size(170, 40)

function Create-MachineCard($maq, $siteColor) {
    $card = New-Object System.Windows.Forms.Panel
    $card.Width = 286
    $card.Height = 152
    $card.Margin = New-Object System.Windows.Forms.Padding(12)
    $card.BackColor = [System.Drawing.Color]::White
    $card.Tag = $maq
    Add-CardShadowBorder $card

    $bar = New-Object System.Windows.Forms.Panel
    $bar.BackColor = $siteColor
    $bar.Location = New-Object System.Drawing.Point(0, 0)
    $bar.Size = New-Object System.Drawing.Size(286, 6)
    $bar.Anchor = "Top,Left,Right"

    $name = New-Object System.Windows.Forms.Label
    $name.Text = "$($maq.nome)"
    $name.Font = $fontCardTitle
    $name.ForeColor = New-Color 15 23 42
    $name.AutoSize = $false
    $name.Location = New-Object System.Drawing.Point(16, 16)
    $name.Size = New-Object System.Drawing.Size(250, 25)
    $name.TextAlign = "MiddleLeft"

    $funcao = New-Object System.Windows.Forms.Label
    $funcao.Text = "$($maq.funcao)"
    $funcao.Font = $fontCardText
    $funcao.ForeColor = New-Color 71 85 105
    $funcao.AutoSize = $false
    $funcao.Location = New-Object System.Drawing.Point(16, 42)
    $funcao.Size = New-Object System.Drawing.Size(250, 22)
    $funcao.TextAlign = "MiddleLeft"

    $idLabel = New-Object System.Windows.Forms.Label
    $idLabel.Text = "ID: $($maq.anydesk_id)"
    $idLabel.Font = $fontCardMono
    $idLabel.ForeColor = New-Color 30 41 59
    $idLabel.AutoSize = $false
    $idLabel.Location = New-Object System.Drawing.Point(16, 66)
    $idLabel.Size = New-Object System.Drawing.Size(250, 22)
    $idLabel.TextAlign = "MiddleLeft"

    $senhaStatus = "senha: nao"
    $senhaColor = New-Color 100 116 139
    if ($maq.PSObject.Properties.Name -contains "senha") {
        if (![string]::IsNullOrWhiteSpace($maq.senha)) {
            $senhaStatus = "senha: sim"
            $senhaColor = New-Color 22 163 74
        }
    }

    $pwdLabel = New-Object System.Windows.Forms.Label
    $pwdLabel.Text = $senhaStatus
    $pwdLabel.Font = New-Object System.Drawing.Font("Segoe UI", 8, [System.Drawing.FontStyle]::Bold)
    $pwdLabel.ForeColor = $senhaColor
    $pwdLabel.AutoSize = $false
    $pwdLabel.Location = New-Object System.Drawing.Point(16, 91)
    $pwdLabel.Size = New-Object System.Drawing.Size(110, 22)
    $pwdLabel.TextAlign = "MiddleLeft"

    $connect = New-Object System.Windows.Forms.Button
    $connect.Text = "Conectar"
    $connect.Font = $fontButton
    $connect.Width = 116
    $connect.Height = 32
    $connect.Location = New-Object System.Drawing.Point(154, 103)
    $connect.BackColor = $siteColor
    $connect.ForeColor = [System.Drawing.Color]::White
    $connect.FlatStyle = "Flat"
    $connect.FlatAppearance.BorderSize = 0
    $connect.Tag = $maq

    $connect.Add_Click({
        param($sender, $eventArgs)

        $m = $sender.Tag

        try {
            if (![string]::IsNullOrWhiteSpace($m.bat)) {
                $batPath = Join-Path $baseDir $m.bat

                if (Test-Path $batPath) {
                    Start-Process -FilePath $batPath -WorkingDirectory $baseDir
                    $status.Text = "Abrindo $($m.nome) pelo BAT..."
                } else {
                    Show-Error "BAT nao encontrado: $batPath"
                }
            }
            else {
                $currentAnyDeskPath = Find-AnyDeskPath

                if ([string]::IsNullOrWhiteSpace($currentAnyDeskPath)) {
                    $clientDir = Join-Path $baseDir "Client"
                    Show-Error "Cliente AnyDesk GADX nao encontrado.`r`n`r`nPasta verificada:`r`n$clientDir`r`n`r`nNomes aceitos:`r`n- anydesk-GADX.exe`r`n- anyudesk-GADX.exe`r`n`r`nO launcher nao usara instalacoes do AnyDesk fora desta pasta."
                    return
                }

                $pwd = ""
                if ($m.PSObject.Properties.Name -contains "senha") {
                    $pwd = $m.senha
                }

                $modo = Open-AnyDeskWithOptionalPassword $currentAnyDeskPath $m.anydesk_id $pwd

                if ($modo -eq "senha") {
                    $status.Text = "Abrindo $($m.nome) no AnyDesk com senha do CSV..."
                } else {
                    $status.Text = "Abrindo $($m.nome) no AnyDesk sem senha embarcada..."
                }
            }
        }
        catch {
            Show-Error "Erro ao abrir a maquina: $($_.Exception.Message)"
        }
    })

    $card.Controls.Add($bar)
    $card.Controls.Add($name)
    $card.Controls.Add($funcao)
    $card.Controls.Add($idLabel)
    $card.Controls.Add($pwdLabel)
    $card.Controls.Add($connect)

    return $card
}

function Build-Tabs($filterText) {
    $tabs.TabPages.Clear()

    $filtered = $global:maquinas

    if (![string]::IsNullOrWhiteSpace($filterText)) {
        $f = $filterText.Trim().ToLowerInvariant()
        $filtered = $global:maquinas | Where-Object {
            ("" + $_.site).ToLowerInvariant().Contains($f) -or
            ("" + $_.nome).ToLowerInvariant().Contains($f) -or
            ("" + $_.funcao).ToLowerInvariant().Contains($f) -or
            ("" + $_.anydesk_id).ToLowerInvariant().Contains($f)
        }
    }

    $groups = $filtered | Group-Object site | Sort-Object Name

    $idx = 0
    foreach ($group in $groups) {
        $siteColor = Get-SiteColor $idx

        $tab = New-Object System.Windows.Forms.TabPage
        $tab.Text = "$($group.Name)  ($($group.Count))"
        $tab.BackColor = New-Color 241 245 249

        $panel = New-Object System.Windows.Forms.FlowLayoutPanel
        $panel.Dock = "Fill"
        $panel.AutoScroll = $true
        $panel.Padding = New-Object System.Windows.Forms.Padding(20)
        $panel.WrapContents = $true
        $panel.BackColor = New-Color 241 245 249

        foreach ($maq in ($group.Group | Sort-Object nome)) {
            $card = Create-MachineCard $maq $siteColor
            $panel.Controls.Add($card) | Out-Null
        }

        $tab.Controls.Add($panel)
        $tabs.TabPages.Add($tab) | Out-Null
        $idx++
    }

    if ($tabs.TabPages.Count -eq 0) {
        $tab = New-Object System.Windows.Forms.TabPage
        $tab.Text = "Sem resultados"
        $tab.BackColor = New-Color 241 245 249

        $empty = New-Object System.Windows.Forms.Label
        $empty.Text = "Nenhuma maquina encontrada para a busca atual."
        $empty.Font = New-Object System.Drawing.Font("Segoe UI", 13, [System.Drawing.FontStyle]::Bold)
        $empty.ForeColor = New-Color 71 85 105
        $empty.Dock = "Fill"
        $empty.TextAlign = "MiddleCenter"

        $tab.Controls.Add($empty)
        $tabs.TabPages.Add($tab) | Out-Null
    }

    $shown = @($filtered).Count
    $totalAll = @($global:maquinas).Count
    if ([string]::IsNullOrWhiteSpace($filterText)) {
        $totalLabel.Text = "$totalAll maquinas cadastradas em $sites sites"
    } else {
        $totalLabel.Text = "$shown de $totalAll maquinas encontradas"
    }
}

$searchBox.Add_TextChanged({
    # Ao reconstruir as abas/cards, o TabControl pode roubar o foco.
    # Depois de filtrar, devolvemos o foco e colocamos o cursor no final do texto.
    # Isso evita o bug de escrever "de tras para frente".
    $currentText = $searchBox.Text

    Build-Tabs $currentText

    $form.BeginInvoke([System.Action]{
        $searchBox.Focus() | Out-Null
        $searchBox.SelectionStart = $searchBox.Text.Length
        $searchBox.SelectionLength = 0
    }) | Out-Null
})

Build-Tabs ""

$form.Controls.Add($tabs)
$form.Controls.Add($bottomPanel)
$form.Controls.Add($searchPanel)
$form.Controls.Add($headerPanel)

[void]$form.ShowDialog()
