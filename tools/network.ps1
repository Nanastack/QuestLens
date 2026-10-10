# Portable TLS client; use the bundled public roots plus this PC's trusted stores.
# Certificate verification remains enabled. No Python or PowerShell upgrade needed.
$questCurl=Join-Path $PSScriptRoot 'curl\bin\curl.exe'
$questCa=Join-Path $cache ('trusted-roots-'+$PID+'.pem')
function Initialize-QuestTls {
    if(Test-Path -LiteralPath $questCa){return}
    $pem=[IO.File]::ReadAllText((Join-Path $PSScriptRoot 'curl\bin\curl-ca-bundle.crt'))
    $seen=@{}
    foreach($location in @('CurrentUser','LocalMachine')) {
        foreach($name in @('Root','CA')) {
            $store=New-Object Security.Cryptography.X509Certificates.X509Store($name,$location)
            try {
                $store.Open([Security.Cryptography.X509Certificates.OpenFlags]::ReadOnly)
                foreach($cert in $store.Certificates) {
                    if($seen.ContainsKey($cert.Thumbprint)){continue}
                    $seen[$cert.Thumbprint]=$true
                    $pem += "`n-----BEGIN CERTIFICATE-----`n"+[Convert]::ToBase64String($cert.RawData,[Base64FormattingOptions]::InsertLineBreaks)+"`n-----END CERTIFICATE-----`n"
                }
            } finally {$store.Close()}
        }
    }
    [IO.File]::WriteAllText($questCa,$pem,[Text.Encoding]::ASCII)
}
function Download-QuestFile([string]$url,[string]$destination) {
    if($url -notmatch '^https://'){throw 'Only HTTPS downloads are supported.'}
    Initialize-QuestTls
    $message=& $questCurl --fail --silent --show-error --location --proto '=https' --proto-redir '=https' --connect-timeout 8 --max-time 20 --cacert $questCa --user-agent 'Mozilla/5.0 QuestLens/1.0' --output $destination --url $url 2>&1
    if($LASTEXITCODE -ne 0){throw ('Wiki download failed: '+($message -join ' '))}
}
function Fetch($url) {
    $file=Join-Path $cache ('response-'+$PID+'.json')
    try {Download-QuestFile $url $file;return ([IO.File]::ReadAllText($file) | ConvertFrom-Json)}
    finally {if(Test-Path -LiteralPath $file){Remove-Item -LiteralPath $file -Force}}
}
function Close-QuestTls {
    if(Test-Path -LiteralPath $questCa){Remove-Item -LiteralPath $questCa -Force}
}
