# مجلِسنا (Majlisna) - خادم الشبكة المحلية للهواتف (Local Wi-Fi Mobile Server)
# يتيح فتح التطبيق على جوالك فوراً بمجرد الاتصال بنفس شبكة الواي فاي أو نقطة الاتصال

$port = 8080
$ip = (Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.InterfaceAlias -notmatch 'Loopback' -and $_.IPAddress -notmatch '^169\.' } | Select-Object -First 1).IPAddress
$baseDir = Split-Path -Parent $MyInvocation.MyCommand.Path

if (-not $ip) { $ip = "127.0.0.1" }

$url = "http://${ip}:${port}"

Write-Host "==========================================================" -ForegroundColor Yellow
Write-Host " ☕ خادم مجلِسنا للهواتف الذكية يعمل الآن بنجاح! " -ForegroundColor Green
Write-Host "==========================================================" -ForegroundColor Yellow
Write-Host " افتح هذا الرابط في متصفح جوالك (Safari / Chrome):" -ForegroundColor Cyan
Write-Host " 👉 $url" -ForegroundColor White -BackgroundColor DarkGreen
Write-Host "==========================================================" -ForegroundColor Yellow
Write-Host " تأكد أن جوالك وجهاز الكمبيوتر متصلان بنفس شبكة الواي فاي." -ForegroundColor Gray
Write-Host " اضغط Ctrl + C لإيقاف الخادم في أي وقت." -ForegroundColor Gray
Write-Host "==========================================================" -ForegroundColor Yellow

$listener = New-Object System.Net.Sockets.TcpListener([System.Net.IPAddress]::Any, $port)
$listener.Start()

$mimeTypes = @{
    ".html" = "text/html; charset=utf-8"
    ".css"  = "text/css; charset=utf-8"
    ".js"   = "application/javascript; charset=utf-8"
    ".json" = "application/json; charset=utf-8"
    ".png"  = "image/png"
    ".jpg"  = "image/jpeg"
    ".jpeg" = "image/jpeg"
    ".svg"  = "image/svg+xml"
    ".webp" = "image/webp"
    ".ico"  = "image/x-icon"
}

try {
    while ($true) {
        $client = $listener.AcceptTcpClient()
        $stream = $client.GetStream()
        $reader = New-Object System.IO.StreamReader($stream)
        $line = $reader.ReadLine()
        
        if ($line) {
            $parts = $line.Split(" ")
            $path = $parts[1]
            if ($path -eq "/" -or $path -like "/?*") {
                $path = "/index.html"
            } else {
                $path = $path.Split("?")[0]
            }
            
            $localPath = Join-Path $baseDir $path.TrimStart("/").Replace("/", "\")
            
            if (Test-Path $localPath -PathType Leaf) {
                $ext = [System.IO.Path]::GetExtension($localPath).ToLower()
                $contentType = if ($mimeTypes.ContainsKey($ext)) { $mimeTypes[$ext] } else { "application/octet-stream" }
                $bytes = [System.IO.File]::ReadAllBytes($localPath)
                
                $header = "HTTP/1.1 200 OK`r`nContent-Type: $contentType`r`nContent-Length: $($bytes.Length)`r`nAccess-Control-Allow-Origin: *`r`nConnection: close`r`n`r`n"
                $headerBytes = [System.Text.Encoding]::UTF8.GetBytes($header)
                $stream.Write($headerBytes, 0, $headerBytes.Length)
                $stream.Write($bytes, 0, $bytes.Length)
            } else {
                $notFound = "HTTP/1.1 404 Not Found`r`nContent-Length: 0`r`nConnection: close`r`n`r`n"
                $notFoundBytes = [System.Text.Encoding]::UTF8.GetBytes($notFound)
                $stream.Write($notFoundBytes, 0, $notFoundBytes.Length)
            }
        }
        
        $stream.Close()
        $client.Close()
    }
} finally {
    $listener.Stop()
}
