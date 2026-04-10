#Requires -Version 7.0
# ============================================================================
# pcHealth — Windows 11 — Reset Network Stack
# ============================================================================

Write-Host "`nResetting and flushing the network stack...`n" -ForegroundColor Cyan

# Clear-DnsClientCache is the PS7 equivalent of 'ipconfig /flushdns'
Write-Host "[>>] Flushing DNS cache..." -ForegroundColor Yellow
Clear-DnsClientCache
Write-Host "[OK] DNS cache flushed." -ForegroundColor Green

# Register-DnsClient re-sends the hostname to the DNS server (like 'ipconfig /registerdns')
Write-Host "[>>] Re-registering DNS..." -ForegroundColor Yellow
Register-DnsClient
Write-Host "[OK] DNS re-registered." -ForegroundColor Green

Write-Host "[>>] Releasing and renewing IP address..." -ForegroundColor Yellow
ipconfig /release | Out-Null
ipconfig /renew   | Out-Null
Write-Host "[OK] IP address renewed." -ForegroundColor Green

# Winsock reset rebuilds the Windows Sockets catalog from scratch.
# Fixes issues caused by malware or broken LSP (Layered Service Provider) entries.
Write-Host "[>>] Resetting Winsock catalog..." -ForegroundColor Yellow
netsh winsock reset catalog | Out-Null
Write-Host "[OK] Winsock reset." -ForegroundColor Green

# Resets the TCP/IP stack to factory defaults. Fixes persistent connectivity
# problems that survive a simple DHCP renew.
Write-Host "[>>] Resetting IPv4/IPv6 stack..." -ForegroundColor Yellow
netsh int ipv4 reset | Out-Null
netsh int ipv6 reset | Out-Null
Write-Host "[OK] IP stack reset." -ForegroundColor Green

Write-Host "`nNetwork stack reset complete. A reboot may be required.`n" -ForegroundColor Green
