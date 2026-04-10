#Requires -Version 7.0
# ============================================================================
# pcHealth — Windows 11 — Short Ping Test
# ============================================================================

Write-Host "`nRunning ping test to 8.8.8.8 (4 packets)...`n" -ForegroundColor Cyan

$results = Test-Connection -TargetName '8.8.8.8' -Count 4 -ErrorAction SilentlyContinue

if ($results) {
    $results | ForEach-Object {
        $status = if ($_.Status -eq 'Success') { 'Reply' } else { 'Timeout' }
        $color  = if ($_.Status -eq 'Success') { 'Green' } else { 'Red' }
        Write-Host "  $status from $($_.DisplayAddress): time=$($_.Latency)ms" -ForegroundColor $color
    }
    $avg = [Math]::Round(($results | Where-Object Status -eq 'Success' | Measure-Object Latency -Average).Average, 1)
    Write-Host "`n  Average latency: ${avg}ms`n" -ForegroundColor Cyan
} else {
    Write-Host "  No response from 8.8.8.8. Check your network connection.`n" -ForegroundColor Red
}
