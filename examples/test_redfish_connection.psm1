function test_redfish_connection {
    param(
        [string]$IpAddress = "10.1.9.82",
        [int]$Port = 443  # Redfish 預設端口
    )
    
    $Uri = "https://${IpAddress}/redfish/v1"
    if ($Port -ne 443) {
        $Uri = "https://${IpAddress}:${Port}/redfish/v1"
    }
    
    Write-Host "測試連接到: $Uri" -ForegroundColor Cyan
    
    # 嘗試不同的 TLS 版本
    $tlsVersions = @(
        @{Name="TLS 1.2"; Type=[System.Net.SecurityProtocolType]::Tls12},
        @{Name="TLS 1.1"; Type=[System.Net.SecurityProtocolType]::Tls11},
        @{Name="TLS 1.0"; Type=[System.Net.SecurityProtocolType]::Tls}
    )
    
    foreach ($tls in $tlsVersions) {
        Write-Host "`n嘗試 $($tls.Name)..." -ForegroundColor Yellow
        
        # 設置 TLS 版本
        [System.Net.ServicePointManager]::SecurityProtocol = $tls.Type
        
        # 跳過 SSL 憑證驗證
        [System.Net.ServicePointManager]::ServerCertificateValidationCallback = {$true}
        
        try {
            $response = Invoke-WebRequest -Uri $Uri -Method Get -UseBasicParsing -TimeoutSec 10
            Write-Host "✓ 成功使用 $($tls.Name)！" -ForegroundColor Green
            Write-Host "狀態碼: $($response.StatusCode)" -ForegroundColor Green
            
            # 顯示部分內容
            $content = $response.Content
            if ($content.Length -gt 200) {
                $content = $content.Substring(0, 200) + "..."
            }
            Write-Host "`n回應內容: $content" -ForegroundColor Cyan
            Write-Host $Uri            
            return $response
        }
        catch {
            Write-Host "✗ 失敗: $($_.Exception.Message)" -ForegroundColor Red
        }
    }
    
    # 嘗試 HTTP（如果 HTTPS 全部失敗）
    Write-Host "`n嘗試 HTTP..." -ForegroundColor Yellow
    $HttpUri = $Uri -replace "https://", "http://"
    
    try {
        $response = Invoke-WebRequest -Uri $HttpUri -Method Get -UseBasicParsing -TimeoutSec 10
        Write-Host "✓ HTTP 成功！" -ForegroundColor Green
        Write-Host $HttpUri
        return $response
    }
    catch {
        Write-Host "✗ HTTP 也失敗" -ForegroundColor Red
    }
    
    Write-Host "`n所有連接嘗試都失敗" -ForegroundColor Red
}

# 執行測試
#test_redfish_connection -IpAddress 10.1.9.82 -Port 49571 # https://10.1.9.82:49571
#test_redfish_connection -IpAddress 10.1.9.82 -Port 443 # https;//10.1.9.82
