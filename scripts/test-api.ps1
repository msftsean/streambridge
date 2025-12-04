# StreamBridge - API Test Script
# Tests various scenarios against the deployed API

param(
    [Parameter(Mandatory=$true)]
    [string]$ApimGatewayUrl,

    [Parameter(Mandatory=$true)]
    [string]$SubscriptionKey,

    [Parameter(Mandatory=$false)]
    [switch]$IncludeRateLimitTest
)

$ErrorActionPreference = "Stop"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "StreamBridge - API Test Suite" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

$apiUrl = "$ApimGatewayUrl/telemetry/uploadTelemetry"
$headers = @{
    "Content-Type" = "application/json"
    "Ocp-Apim-Subscription-Key" = $SubscriptionKey
}

function Test-Scenario {
    param(
        [string]$Name,
        [hashtable]$Body,
        [int]$ExpectedStatus = 200
    )

    Write-Host "`n----------------------------------------" -ForegroundColor Gray
    Write-Host "Test: $Name" -ForegroundColor Yellow
    Write-Host "----------------------------------------" -ForegroundColor Gray

    $jsonBody = $Body | ConvertTo-Json -Depth 10

    try {
        $response = Invoke-WebRequest `
            -Uri $apiUrl `
            -Method POST `
            -Headers $headers `
            -Body $jsonBody `
            -UseBasicParsing

        $statusCode = $response.StatusCode
        $content = $response.Content | ConvertFrom-Json

        if ($statusCode -eq $ExpectedStatus) {
            Write-Host "✓ PASSED - Status: $statusCode" -ForegroundColor Green
        } else {
            Write-Host "✗ FAILED - Expected: $ExpectedStatus, Got: $statusCode" -ForegroundColor Red
        }

        Write-Host "Response:" -ForegroundColor Gray
        Write-Host ($content | ConvertTo-Json -Depth 5)

        return @{
            Success = $statusCode -eq $ExpectedStatus
            StatusCode = $statusCode
            Content = $content
        }
    }
    catch {
        $statusCode = $_.Exception.Response.StatusCode.value__

        if ($statusCode -eq $ExpectedStatus) {
            Write-Host "✓ PASSED - Status: $statusCode (expected error)" -ForegroundColor Green
        } else {
            Write-Host "✗ FAILED - Expected: $ExpectedStatus, Got: $statusCode" -ForegroundColor Red
        }

        return @{
            Success = $statusCode -eq $ExpectedStatus
            StatusCode = $statusCode
            Error = $_.ErrorDetails.Message
        }
    }
}

# Track results
$results = @()

# Test 1: Basic Telemetry (Metrics)
$results += Test-Scenario -Name "Basic Telemetry - Metrics" -Body @{
    deviceId = "test-device-001"
    region = "eastus"
    timestamp = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
    telemetryType = "metrics"
    data = @{
        cpu = 45.2
        memory = 72.1
        diskUsage = 55.0
    }
}

Start-Sleep -Seconds 2

# Test 2: Telemetry with Events
$results += Test-Scenario -Name "Telemetry - Events" -Body @{
    deviceId = "test-device-002"
    region = "westus2"
    timestamp = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
    telemetryType = "events"
    data = @{
        eventName = "ApplicationStarted"
        eventData = @{
            version = "1.0.0"
            platform = "Windows"
        }
    }
}

Start-Sleep -Seconds 2

# Test 3: Crash Dump Processing
$results += Test-Scenario -Name "Crash Dump Processing" -Body @{
    deviceId = "test-device-003"
    region = "centralus"
    timestamp = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
    telemetryType = "crashDump"
    data = @{
        lastKnownState = "running"
        uptime = 7200
    }
    crashDump = @{
        dumpId = "dump-" + [guid]::NewGuid().ToString().Substring(0,8)
        errorCode = "0xC0000005"
        stackTrace = "ntdll.dll!RtlUserThreadStart`nkernel32.dll!BaseThreadInitThunk`nmyapp.exe!ProcessData`nmyapp.exe!main"
        processName = "myapp.exe"
        memoryDumpUrl = "https://storage.blob.core.windows.net/dumps/crash.dmp"
    }
}

Start-Sleep -Seconds 2

# Test 4: Different Error Codes
$results += Test-Scenario -Name "Crash Dump - Out of Memory" -Body @{
    deviceId = "test-device-004"
    region = "northeurope"
    timestamp = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
    telemetryType = "crashDump"
    data = @{}
    crashDump = @{
        dumpId = "dump-oom-001"
        errorCode = "0x8007000E"
        stackTrace = "malloc+0x45`noperator new+0x12`nstd::vector::push_back"
        processName = "dataprocessor.exe"
    }
}

Start-Sleep -Seconds 2

# Test 5: Missing Required Fields (Expected 400)
$results += Test-Scenario -Name "Invalid Payload - Missing Fields" -ExpectedStatus 400 -Body @{
    someField = "test"
}

Start-Sleep -Seconds 2

# Test 6: Multiple regions for partition testing
$regions = @("eastus", "westus2", "centralus", "northeurope", "westeurope")
foreach ($region in $regions) {
    $results += Test-Scenario -Name "Multi-Region Test - $region" -Body @{
        deviceId = "region-test-device"
        region = $region
        timestamp = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
        telemetryType = "metrics"
        data = @{
            region = $region
            testRun = [guid]::NewGuid().ToString()
        }
    }
    Start-Sleep -Milliseconds 500
}

# Optional: Rate Limit Test
if ($IncludeRateLimitTest) {
    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host "Rate Limit Test (sending 110 requests)" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan

    $rateLimitHit = $false
    $successCount = 0
    $failCount = 0

    1..110 | ForEach-Object {
        $body = @{
            deviceId = "rate-limit-test"
            region = "eastus"
            timestamp = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
            telemetryType = "metrics"
            data = @{ requestNumber = $_ }
        } | ConvertTo-Json

        try {
            $null = Invoke-WebRequest -Uri $apiUrl -Method POST -Headers $headers -Body $body -UseBasicParsing
            $successCount++
            Write-Host "." -NoNewline -ForegroundColor Green
        }
        catch {
            $failCount++
            if (-not $rateLimitHit) {
                $rateLimitHit = $true
                Write-Host "`nRate limit triggered at request $_" -ForegroundColor Yellow
            }
            Write-Host "x" -NoNewline -ForegroundColor Red
        }
    }

    Write-Host ""
    Write-Host "Success: $successCount, Rate Limited: $failCount" -ForegroundColor $(if ($rateLimitHit) { "Green" } else { "Red" })

    $results += @{
        Success = $rateLimitHit
        Test = "Rate Limiting"
        SuccessCount = $successCount
        FailCount = $failCount
    }
}

# Summary
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Test Summary" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

$passed = ($results | Where-Object { $_.Success }).Count
$total = $results.Count

Write-Host "Passed: $passed / $total" -ForegroundColor $(if ($passed -eq $total) { "Green" } else { "Yellow" })

if ($passed -lt $total) {
    Write-Host "`nFailed Tests:" -ForegroundColor Red
    $results | Where-Object { -not $_.Success } | ForEach-Object {
        Write-Host "  - $($_.Test): Status $($_.StatusCode)" -ForegroundColor Red
    }
}

Write-Host "`nDone!" -ForegroundColor Green
