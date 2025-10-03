# Otimizador PostgreSQL

## Como Gerar o Executável

### Pré-requisitos
- Windows PowerShell 5.1 ou superior
- Permissões de administrador

### Passos para Criar o Executável

1. **Abra o PowerShell como Administrador**
   - Clique com botão direito no PowerShell
   - Selecione "Executar como administrador"

2. **Configure a Política de Execução**
   ```powershell
   Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
   ```

3. **Execute o Script de Build**
   ```powershell
   .\build.ps1
   ```

4. **Aguarde a Conclusão**
   - O script irá instalar o módulo PS2EXE
   - Gerará o arquivo `OtimizadorPSQL.exe`

### Resultado
Após a execução, você terá:
- `OtimizadorPSQL.exe` - Executável principal
- Arquivo original `.ps1` mantido como backup

### Uso do Executável
- Execute `OtimizadorPSQL.exe` como administrador
- Todas as funcionalidades do script original estarão disponíveis

### Observações
- O executável requer privilégios de administrador
- Funciona independente do PowerShell estar visível
- Mantém todas as funcionalidades do script original