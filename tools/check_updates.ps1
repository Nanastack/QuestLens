param([Parameter(Mandatory=$true)][string]$Baseline,[string]$FixtureJson,[switch]$UpdateData,[string]$FixtureRoot,[string]$FixtureItems)
$ErrorActionPreference='Stop'
if ($Baseline -notmatch '^[a-f0-9]{40}$') { exit 1 }
$cache=Join-Path (Split-Path $PSScriptRoot -Parent) 'cache'
[IO.Directory]::CreateDirectory($cache) | Out-Null
$dest=Join-Path $cache 'source-status.json'
[Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12
. (Join-Path $PSScriptRoot 'network.ps1')
try {
    if ($FixtureJson) { $data=[IO.File]::ReadAllText($FixtureJson) | ConvertFrom-Json }
    else { $data=Fetch 'https://api.github.com/repos/phoenixffxi/Phoenix/commits/base' }
    if ($data.sha -notmatch '^[a-f0-9]{40}$') { throw 'Invalid source revision response.' }
    $result=@{time=[DateTimeOffset]::UtcNow.ToUnixTimeSeconds();sha=$data.sha;baseline=$Baseline;changed=($data.sha -ne $Baseline)}
    if($UpdateData){
        $built=& (Join-Path $PSScriptRoot 'build_source_data.ps1') -Sha $data.sha -FixtureRoot $FixtureRoot -FixtureItems $FixtureItems
        $result.time=[DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
        $result.dataReady=$true;$result.counts=$built
    }
} catch { $result=@{time=[DateTimeOffset]::UtcNow.ToUnixTimeSeconds();baseline=$Baseline;error=$_.Exception.Message} }
$json=$result | ConvertTo-Json -Depth 5 -Compress
[IO.File]::WriteAllText($dest+'.tmp',$json,[Text.UTF8Encoding]::new($false))
Move-Item -LiteralPath ($dest+'.tmp') -Destination $dest -Force
Close-QuestTls
