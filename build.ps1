# Script para gerar executável
Install-Module -Name ps2exe -Force -Scope CurrentUser
Import-Module ps2exe

# Gerar o executável
ps2exe -inputFile "OtimizadorPSQL.ps1" -outputFile "OtimizadorPSQL.exe" -requireAdmin -title "Otimizador PostgreSQL" -description "Otimizador PostgreSQL by nathanbrito.sup.pack" -version "1.0.0.0"