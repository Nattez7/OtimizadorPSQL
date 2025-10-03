# Script PowerShell para Otimização do PostgreSQL com Backup, Logs e Configurações

function Backup-Config {
    param (
        [string]$ConfigPath,
        [string]$Version
    )

    $BackupFolder = "C:\PostgreSQL_Optimizer\Logs"
    if (-not (Test-Path $BackupFolder)) {
        New-Item -ItemType Directory -Path $BackupFolder | Out-Null
    }

    $VersionFolder = Join-Path $BackupFolder $Version
    if (-not (Test-Path $VersionFolder)) {
        New-Item -ItemType Directory -Path $VersionFolder | Out-Null
    }

    $Timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $BackupPath = Join-Path $VersionFolder "postgresql_backup_$Timestamp.conf"

    Copy-Item -Path $ConfigPath -Destination $BackupPath
    Write-Host "Backup criado com sucesso em $BackupPath" -ForegroundColor Green

    return $BackupPath
}

function Write-Changes {
    param (
        [string]$LogPath,
        [hashtable]$Configurations
    )

    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $ComputerName = $env:COMPUTERNAME
    $UserName = $env:USERNAME
    
    $Separator = "=" * 80
    
    Add-Content -Path $LogPath -Value $Separator
    Add-Content -Path $LogPath -Value "[$Timestamp] [INFO] PostgreSQL Optimization Log"
    Add-Content -Path $LogPath -Value "Computer: $ComputerName"
    Add-Content -Path $LogPath -Value "User: $UserName"
    Add-Content -Path $LogPath -Value "Process: PostgreSQL Configuration Optimization"
    Add-Content -Path $LogPath -Value $Separator
    Add-Content -Path $LogPath -Value "[$Timestamp] [INFO] Starting configuration changes..."
    
    foreach ($Key in $Configurations.Keys) {
        Add-Content -Path $LogPath -Value "[$Timestamp] [CONFIG] $Key = $($Configurations[$Key])"
    }
    
    Add-Content -Path $LogPath -Value "[$Timestamp] [INFO] Configuration changes completed successfully"
    Add-Content -Path $LogPath -Value "[$Timestamp] [INFO] Total parameters modified: $($Configurations.Count)"
    Add-Content -Path $LogPath -Value ""
    
    Write-Host "Log atualizado em $LogPath" -ForegroundColor Yellow
}

function Restart-Database {
    param (
        [string]$Version
    )

    Write-Host "Finalizando processos do PostgreSQL..." -ForegroundColor Yellow
    Stop-Process -Name postgres -Force -ErrorAction SilentlyContinue

    $DataPath = if ($Version -eq "9.6") {
        "C:\Program Files\PostgreSQL\9.6\data"
    } else {
        "C:\Program Files\PostgreSQL\11\data"
    }

    Write-Host "Excluindo postmaster.pid..." -ForegroundColor Yellow
    Remove-Item -Path "$DataPath\postmaster.pid" -Force -ErrorAction SilentlyContinue

    if ($Version -eq "9.6") {
        Write-Host "Reiniciando log do PostgreSQL 9.6..." -ForegroundColor Yellow
        & "C:\Program Files\PostgreSQL\9.6\bin\pg_resetxlog.exe" -f "$DataPath"
    } else {
        Write-Host "Reiniciando log do PostgreSQL 11..." -ForegroundColor Yellow
        & "C:\Program Files\PostgreSQL\11\bin\pg_resetwal.exe" -f "$DataPath"
    }

    Write-Host "Iniciando serviço do PostgreSQL..." -ForegroundColor Yellow
    
    # Buscar o serviço PostgreSQL automaticamente
    $PostgreSQLService = Get-Service | Where-Object { $_.Name -like "*postgresql*" -and $_.Name -like "*$Version*" } | Select-Object -First 1
    
    if ($PostgreSQLService) {
        Write-Host "Serviço encontrado: $($PostgreSQLService.Name)" -ForegroundColor Green
        Start-Service -Name $PostgreSQLService.Name
    } else {
        Write-Host "Serviço PostgreSQL não encontrado. Tentando nomes padrão..." -ForegroundColor Yellow
        $ServiceNames = if ($Version -eq "9.6") { @("postgresql-x64-9.6", "postgresql-9.6") } else { @("postgresql-x64-11", "postgresql-11") }
        
        foreach ($ServiceName in $ServiceNames) {
            try {
                Start-Service -Name $ServiceName -ErrorAction Stop
                Write-Host "Serviço iniciado: $ServiceName" -ForegroundColor Green
                break
            } catch {
                Write-Host "Tentativa falhou para: $ServiceName" -ForegroundColor Yellow
            }
        }
    }

    Write-Host "Processo de reinicialização concluído com sucesso." -ForegroundColor Green
}

function Show-EndMenu {
    Write-Host "[1] - Voltar ao menu inicial" -ForegroundColor White
    Write-Host "[2] - Sair do sistema" -ForegroundColor White
    $EndChoice = Read-Host "Digite a opção desejada (1 ou 2)"
    
    switch ($EndChoice) {
        1 { return $true }
        2 { 
            Write-Host "Saindo do sistema. Até logo!" -ForegroundColor Yellow
            return $false
        }
        default {
            Write-Host "Opção inválida. Saindo do sistema." -ForegroundColor Red
            return $false
        }
    }
}

function Set-Permissions {
    # Pastas para verificar
    $Folders = @(
        "C:\Program Files\PostgreSQL"
    )

    # Chaves de registro para verificar
    $RegistryKeys = @(
        "HKLM:\SOFTWARE\PostgreSQL"
    )

    Write-Host "Iniciando verificação e aplicação de permissões..." -ForegroundColor Cyan

    # Verificar e aplicar permissões nas pastas
    foreach ($Folder in $Folders) {
        if (Test-Path $Folder) {
            Write-Host "Verificando permissões na pasta: $Folder" -ForegroundColor Yellow
            $ACL = Get-Acl $Folder
            $HasPermission = $ACL.Access | Where-Object {
                $_.IdentityReference -like "Todos" -and $_.FileSystemRights -contains "FullControl"
            }

            if ($HasPermission) {
                Write-Host "Permissão de 'Todos' com controle total encontrada na pasta $Folder" -ForegroundColor Green
            } else {
                Write-Host "Permissão de 'Todos' com controle total não encontrada na pasta $Folder. Aplicando..." -ForegroundColor Red
                try {
                    $AccessRule = New-Object System.Security.AccessControl.FileSystemAccessRule("Todos", "FullControl", "ContainerInherit,ObjectInherit", "None", "Allow")
                    $ACL.AddAccessRule($AccessRule)
                    Set-Acl -Path $Folder -AclObject $ACL
                    Write-Host "Permissão de 'Todos' aplicada com sucesso na pasta $Folder" -ForegroundColor Green
                } catch {
                    Write-Host "Erro ao aplicar permissões na pasta $Folder $_" -ForegroundColor Red
                }
            }
        } else {
            Write-Host "Pasta não encontrada: $Folder. Pulando..." -ForegroundColor Yellow
        }
    }

    # Verificar e aplicar permissões nas chaves de registro
    foreach ($Key in $RegistryKeys) {
        if (Test-Path $Key) {
            Write-Host "Verificando permissões na chave de registro: $Key" -ForegroundColor Yellow
            try {
                $ACL = Get-Acl $Key
                $HasPermission = $ACL.Access | Where-Object {
                    $_.IdentityReference -like "Todos" -and $_.RegistryRights -contains "FullControl"
                }

                if ($HasPermission) {
                    Write-Host "Permissão de 'Todos' com controle total encontrada na chave $Key" -ForegroundColor Green
                } else {
                    Write-Host "Permissão de 'Todos' com controle total não encontrada na chave $Key. Aplicando..." -ForegroundColor Red
                    $AccessRule = New-Object System.Security.AccessControl.RegistryAccessRule("Todos", "FullControl", "ContainerInherit,ObjectInherit", "None", "Allow")
                    $ACL.AddAccessRule($AccessRule)
                    Set-Acl -Path $Key -AclObject $ACL
                    Write-Host "Permissão de 'Todos' aplicada com sucesso na chave $Key" -ForegroundColor Green
                }
            } catch {
                Write-Host "Erro ao aplicar permissões na chave $Key $_" -ForegroundColor Red
            }
        } else {
            Write-Host "Chave de registro não encontrada: $Key. Pulando..." -ForegroundColor Yellow
        }
    }

    Write-Host "Verificação e aplicação de permissões concluída." -ForegroundColor Cyan
    Write-Host "Procedimento Finalizado!" -ForegroundColor Yellow
    Show-EndMenu
}

function Optimize-PostgreSQL {
    param (
        [int]$Stations,
        [string]$Version, # 9.6 ou 11
        [string]$ConfigPath
    )

    Backup-Config -ConfigPath $ConfigPath -Version $Version | Out-Null

    $CPUCount = (Get-WmiObject -Class Win32_Processor).NumberOfLogicalProcessors
    $RAMGB = [math]::Floor((Get-WmiObject -Class Win32_ComputerSystem).TotalPhysicalMemory / 1GB)
    $DiskType = if ((Get-PhysicalDisk | Where-Object MediaType -eq "SSD").Count -gt 0) { "SSD" } else { "HD" }

    $MaxConnections = [math]::Max([math]::Ceiling($Stations * 10.5), 150)
    $SharedBuffers = [math]::Ceiling($RAMGB * 0.25)
    $EffectiveCacheSize = [math]::Ceiling($RAMGB * 0.75)
    $MaintenanceWorkMem = 1
    $WorkMem = [math]::Max([math]::Ceiling((($RAMGB * 1024 - $SharedBuffers) / ($MaxConnections * 2)) / 10) * 10, 4)
    $WalBuffers = [math]::Max([math]::Ceiling($SharedBuffers * 0.03), 16)

    $CheckpointCompletionTarget = 0.9
    $DefaultStatisticsTarget = 100
    $RandomPageCost = if ($DiskType -eq "SSD") { 1.1 } else { 4.0 }
    $HugePages = "off"
    $MinWalSize = "1GB"
    $MaxWalSize = "4GB"
    $MaxWorkerProcesses = $CPUCount
    $MaxParallelWorkersPerGather = [math]::Max([math]::Ceiling($CPUCount / 2), 2)
    $MaxParallelWorkers = $CPUCount
    $MaxParallelMaintenanceWorkers = [math]::Max([math]::Ceiling($CPUCount / 2), 2)
    $max_locks_per_transaction = 800

    $Configurations = @{
        "max_connections" = $MaxConnections
        "shared_buffers" = "${SharedBuffers}GB"
        "effective_cache_size" = "${EffectiveCacheSize}GB"
        "maintenance_work_mem" = "${MaintenanceWorkMem}GB"
        "work_mem" = "${WorkMem}MB"
        "wal_buffers" = "${WalBuffers}MB"
        "checkpoint_completion_target" = $CheckpointCompletionTarget
        "default_statistics_target" = $DefaultStatisticsTarget
        "random_page_cost" = $RandomPageCost
        "huge_pages" = $HugePages
        "min_wal_size" = $MinWalSize
        "max_wal_size" = $MaxWalSize
        "max_worker_processes" = $MaxWorkerProcesses
        "max_parallel_workers_per_gather" = $MaxParallelWorkersPerGather
        "max_parallel_workers" = $MaxParallelWorkers
        "max_parallel_maintenance_workers" = $MaxParallelMaintenanceWorkers
        "max_locks_per_transaction" = $max_locks_per_transaction
    }

    $FileContent = Get-Content -Path $ConfigPath

    foreach ($Key in $Configurations.Keys) {
        $Regex = "^#?$Key\s*=.*"
        $NewLine = "$Key = $($Configurations[$Key])"

        if ($FileContent -match $Regex) {
            $FileContent = $FileContent -replace $Regex, $NewLine
        } else {
            $FileContent += $NewLine
        }
    }

    $FileContent | Set-Content -Path $ConfigPath

    $LogFolder = "C:\PostgreSQL_Optimizer\Logs"
    if (-not (Test-Path $LogFolder)) {
        New-Item -ItemType Directory -Path $LogFolder -Force | Out-Null
    }
    $LogPath = Join-Path $LogFolder "log_$Version.txt"
    Write-Changes -LogPath $LogPath -Configurations $Configurations

    Restart-Database -Version $Version
    Write-Host "Configurações otimizadas aplicadas com sucesso em" -ForegroundColor Green
    Write-Host $ConfigPath -ForegroundColor Yellow
    Write-Host "Parabéns! Seu Banco de Dados foi otimizado da forma correta. Caso tenha algum problema com a otimização, entre em contato com o suporte para o ajuste correto!" -ForegroundColor Yellow
    Show-EndMenu
}

function Main {
    do {
        Clear-Host
        Write-Host "===============================================" -ForegroundColor Cyan
        Write-Host "       BEM-VINDO AO OTIMIZADOR DO POSTGRESQL"    -ForegroundColor Green
        Write-Host "             DESENVOLVIDO POR NATTEZ"            -ForegroundColor Green
        Write-Host "===============================================" -ForegroundColor Cyan

        Write-Host "Selecione a opção desejada:" -ForegroundColor Yellow
        Write-Host "[1] - Otimizar PostgreSQL" -ForegroundColor White
        Write-Host "[2] - Aplicar Permissões" -ForegroundColor White
        Write-Host "[3] - Sair do sistema" -ForegroundColor White

        $Choice = Read-Host "Digite a opção desejada (1, 2 ou 3)"
        $ContinueLoop = $false

        switch ($Choice) {
            1 {
                Write-Host "Selecione a versão do PostgreSQL para otimizar:" -ForegroundColor Yellow
                Write-Host "[1] - PostgreSQL 9.6" -ForegroundColor White
                Write-Host "[2] - PostgreSQL 11" -ForegroundColor White
                Write-Host "[3] - Voltar" -ForegroundColor White

                $VersionChoice = Read-Host "Digite a opção desejada (1, 2 ou 3)"

                $Version = switch ($VersionChoice) {
                    1 { "9.6" }
                    2 { "11" }
                    3 { $ContinueLoop = $true; break }
                    default {
                        Write-Host "Versão inválida. Tente novamente." -ForegroundColor Red
                        $ContinueLoop = $true
                        break
                    }
                }

                if ($ContinueLoop) { continue }

                $DefaultPath = if ($Version -eq "11") {
                    "C:\Program Files\PostgreSQL\11\data\postgresql.conf"
                } else {
                    "C:\Program Files\PostgreSQL\9.6\data\postgresql.conf"
                }

                Write-Host "O PostgreSQL foi instalado em outro disco? (S/N):" -ForegroundColor Yellow
                $OtherDisk = Read-Host

                if ($OtherDisk -eq "S") {
                    Write-Host "Informe o caminho completo para a **pasta data** do PostgreSQL:" -ForegroundColor Yellow
                    $CustomDataPath = Read-Host "Caminho da pasta data"

                    if (-not (Test-Path $CustomDataPath)) {
                        Write-Host "O caminho informado não existe. Verifique e tente novamente." -ForegroundColor Red
                        $ContinueLoop = $true
                        continue
                    }

                    $ConfigPath = Join-Path $CustomDataPath "postgresql.conf"
                } else {
                    $ConfigPath = $DefaultPath
                }

                Write-Host "Informe o número de estações conectadas ao PostgreSQL:" -ForegroundColor Yellow
                $Stations = [int](Read-Host "Número de estações")

                if (-not (Test-Path $ConfigPath)) {
                    Write-Host "O arquivo postgresql.conf não foi encontrado no caminho especificado: $ConfigPath" -ForegroundColor Red
                    $ContinueLoop = $true
                    continue
                }

                Optimize-PostgreSQL -Stations $Stations -Version $Version -ConfigPath $ConfigPath
                $MenuResult = Show-EndMenu
                if (-not $MenuResult) { return }
                $ContinueLoop = $true
            }
            2 {
                Set-Permissions
                $MenuResult = Show-EndMenu
                if (-not $MenuResult) { return }
                $ContinueLoop = $true
            }
            3 {
                Write-Host "Saindo do sistema. Até logo!" -ForegroundColor Yellow
                return
            }
            default {
                Write-Host "Opção inválida. Tente novamente." -ForegroundColor Red
                $ContinueLoop = $true
            }
        }
    } while ($ContinueLoop)
}

# Executar o programa principal
Main
