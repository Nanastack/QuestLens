param([Parameter(Mandatory=$true)][string]$Sha,[string]$FixtureRoot,[string]$FixtureItems)
$ErrorActionPreference='Stop'
if($Sha -notmatch '^[a-f0-9]{40}$'){throw 'Invalid Phoenix source revision.'}
$root=Split-Path $PSScriptRoot -Parent
$cache=Join-Path $root 'cache'
. (Join-Path $PSScriptRoot 'network.ps1')
function Norm([string]$s){return ($s.ToLowerInvariant() -replace '[^a-z0-9]','')}
function Save-Progress([string]$message){
 $body=@{time=[DateTimeOffset]::UtcNow.ToUnixTimeSeconds();sha=$Sha;running=$true;message=$message}|ConvertTo-Json -Compress
 [IO.File]::WriteAllText((Join-Path $cache 'source-status.json.tmp'),$body,[Text.UTF8Encoding]::new($false))
 Move-Item -LiteralPath (Join-Path $cache 'source-status.json.tmp') -Destination (Join-Path $cache 'source-status.json') -Force
}
function Balanced([string]$s,[int]$start,[char]$open,[char]$close){
 $depth=0
 for($i=$start;$i -lt $s.Length;$i++){
  if($s[$i] -eq $open){$depth++}elseif($s[$i] -eq $close){$depth--;if($depth -eq 0){return $s.Substring($start,$i-$start+1)}}
 }
 return ''
}
try {
 $manifest=Get-Content -LiteralPath (Join-Path $root 'data/update_manifest.json') -Raw|ConvertFrom-Json
 $approved=@{};foreach($q in $manifest.quests){$approved[$q.group+':'+$q.symbol]=$q}
 $sources=@{}
 if($FixtureRoot){
  foreach($file in Get-ChildItem -LiteralPath $FixtureRoot -Filter '*.lua'){$sources[$file.Name]=[IO.File]::ReadAllText($file.FullName)}
  $itemText=[IO.File]::ReadAllText($FixtureItems)
 }else{
  Save-Progress 'Downloading Phoenix quest-script list...'
  $tree=Fetch ('https://api.github.com/repos/phoenixffxi/Phoenix/git/trees/'+$Sha+'?recursive=1')
  if($tree.truncated){throw 'Phoenix source tree is incomplete.'}
  $paths=@($tree.tree|Where-Object {$_.type -eq 'blob' -and $_.path -match '^scripts/quests/(sandoria|bastok|windurst|jeuno|otherAreas|outlands|ahtUrhgan)/[A-Za-z0-9_ .!''()\-]+\.lua$'}|ForEach-Object {$_.path})
  if($paths.Count -lt 100 -or $paths.Count -gt 1500){throw 'Unexpected quest-script count.'}
  $stage=Join-Path $cache ('source-stage-'+$PID)
  [IO.Directory]::CreateDirectory($stage)|Out-Null
  Initialize-QuestTls
  $config=Join-Path $stage 'downloads.conf';$lines=New-Object 'Collections.Generic.List[string]'
  foreach($path in ($paths+@('scripts/enum/item.lua'))){
   $dest=Join-Path $stage ($path -replace '/','_')
   $encoded=(($path -split '/')|ForEach-Object {[Uri]::EscapeDataString($_)}) -join '/'
   foreach($option in @('fail','silent','show-error','location','connect-timeout = 10','max-time = 40','retry = 1','proto = "=https"','proto-redir = "=https"')){$lines.Add($option)}
   $lines.Add('cacert = "'+($questCa -replace '\\','/')+'"')
   $lines.Add('user-agent = "QuestLens/1.0"')
   $lines.Add('url = "https://raw.githubusercontent.com/phoenixffxi/Phoenix/'+$Sha+'/'+$encoded+'"')
   $lines.Add('output = "'+($dest -replace '\\','/')+'"');$lines.Add('next')
  }
  $lines.RemoveAt($lines.Count-1) # A trailing next would create an empty transfer.
  [IO.File]::WriteAllLines($config,$lines,[Text.UTF8Encoding]::new($false))
  Save-Progress ('Downloading '+$paths.Count+' quest scripts (up to ToAU)...')
  $messages=& $questCurl --parallel --parallel-max 8 --fail --silent --show-error --location --proto '=https' --proto-redir '=https' --connect-timeout 10 --max-time 40 --retry 1 --cacert $questCa --user-agent 'QuestLens/1.0' --config $config 2>&1
  if($LASTEXITCODE -ne 0){throw ('Phoenix script download failed: '+($messages -join ' '))}
  foreach($path in $paths){
   $text=[IO.File]::ReadAllText((Join-Path $stage ($path -replace '/','_')))
   if($text.Length -lt 40 -or $text.StartsWith('<')){throw 'Invalid quest-script download.'}
   $sources[$path]=$text
  }
  $itemText=[IO.File]::ReadAllText((Join-Path $stage 'scripts_enum_item.lua'))
 }
 $constants=@{}
 foreach($m in [regex]::Matches($itemText,'(?m)^\s*(\w+)\s*=\s*(\d+)')){$constants[$m.Groups[1].Value]=[int]$m.Groups[2].Value}
 if($constants.Count -lt 100){throw 'Item constant download is incomplete.'}
 Save-Progress 'Building item uses, starter NPCs and repeatable turn-ins...'
 $npcs=New-Object 'Collections.Generic.List[object]';$items=@{};$repeat=@{};$unique=@{};$scanned=0
 foreach($raw in $sources.Values){
  $s=[regex]::Replace($raw,'--[^\n]*','')
  $q=[regex]::Match($s,'Quest:new\(xi.questLog\.(\w+),\s*xi.quest.id\.\w+\.(\w+)\)')
  if(-not $q.Success){continue}
  $group=$q.Groups[1].Value;$symbol=$q.Groups[2].Value;$entry=$approved[$group+':'+(Norm $symbol)]
  if(-not $entry){continue};$scanned++
  $requirements=@{};$rewards=@{}
  foreach($call in [regex]::Matches($s,'(?:tradeHasExactly|tradeHas|hasItemQty|getItemQty|hasItemId|hasItem|tradeItem)\s*\(')){
   $body=Balanced $s ($call.Index+$call.Length-1) '(' ')'
   foreach($m in [regex]::Matches($body,'xi.item\.(\w+)')){if($constants.ContainsKey($m.Groups[1].Value)){$requirements[$constants[$m.Groups[1].Value]]=$true}}
   foreach($name in @('requiredItems','tradeItems','itemsRequired')){
    if($body -match ('\b'+$name+'\b')){
     $assignment=[regex]::Match($s,'\b'+$name+'\s*=\s*\{')
     if($assignment.Success){
      $table=Balanced $s ($assignment.Index+$assignment.Length-1) '{' '}'
      foreach($m in [regex]::Matches($table,'xi.item\.(\w+)')){if($constants.ContainsKey($m.Groups[1].Value)){$requirements[$constants[$m.Groups[1].Value]]=$true}}
     }
    }
   }
  }
  foreach($call in [regex]::Matches($s,'(?:giveItem|addItem)\s*\(')){
   $body=Balanced $s ($call.Index+$call.Length-1) '(' ')'
   foreach($m in [regex]::Matches($body,'xi.item\.(\w+)')){if($constants.ContainsKey($m.Groups[1].Value)){$rewards[$constants[$m.Groups[1].Value]]=$true}}
  }
  foreach($m in [regex]::Matches($s,'\breward\s*=\s*\{')){
   $body=Balanced $s ($m.Index+$m.Length-1) '{' '}'
   foreach($r in [regex]::Matches($body,'xi.item\.(\w+)')){if($constants.ContainsKey($r.Groups[1].Value)){$rewards[$constants[$r.Groups[1].Value]]=$true}}
  }
  foreach($id in $requirements.Keys){
   if($id -eq 4094 -or $rewards.ContainsKey($id)){continue}
   $key=[string]$id;if(-not $items.ContainsKey($key)){$items[$key]=New-Object 'Collections.Generic.List[object]'}
   $items[$key].Add(@{title=$entry.title;group=$group;symbol=$symbol})
  }
  $available=[regex]::Match($s,'status\s*==\s*xi.questStatus.QUEST_AVAILABLE')
  if(-not $available.Success){continue}
  $section=($s.Substring($available.Index+$available.Length) -split 'check = function',2)[0]
  $npc=$null
  foreach($candidateNpc in [regex]::Matches($section,'\[[''"]([^''"]+)[''"]\]\s*=\s*(?:\{|function\b|quest:progress(?:Event|Cutscene)\(|quest:event\(\s*\d+)')){
   if($candidateNpc.Value -match 'quest:event\(\s*(\d+)'){
    $eventId=$Matches[1]
    $eventHandler=[regex]::Match($section,'(?s)\['+$eventId+'\]\s*=\s*function\b(.*?)(?=\n\s*\[|\z)')
    if(-not $eventHandler.Success -or $eventHandler.Groups[1].Value -notmatch 'quest:begin\(player\)'){continue}
   }
   $npc=$candidateNpc;break
  }
  if(-not $npc){continue}
  $name=$npc.Groups[1].Value;$nameSpace=$name -replace '_',' '
  $pattern='--\s*(?:'+[regex]::Escape($name)+'|'+[regex]::Escape($nameSpace)+')(?=[\s,:])[^!\r\n]*!pos\s+[-\d.]+\s+[-\d.]+\s+[-\d.]+\s+(\d+)'
  $position=[regex]::Match($raw,$pattern)
  if($position.Success){$zone=[int]$position.Groups[1].Value}
  else{
   $zoneRefs=[regex]::Matches($section.Substring(0,$npc.Index),'\[xi.zone\.(\w+)\]')
   if($zoneRefs.Count -eq 0){continue}
   $locationKey=(Norm $zoneRefs[$zoneRefs.Count-1].Groups[1].Value)+':'+(Norm $name)
   $locations=Get-Content -LiteralPath (Join-Path $PSScriptRoot '..\data\npc_locations.json') -Raw | ConvertFrom-Json
   $location=$locations.PSObject.Properties[$locationKey]
   if(-not $location){continue}
   $zone=[int]$location.Value
  }
  $key=$zone.ToString()+':'+(Norm $name)+':'+$group+':'+$entry.id
  if(-not $unique.ContainsKey($key)){
   $unique[$key]=$true;$npcs.Add(@{zone=$zone;npc=$nameSpace;group=$group;id=[int]$entry.id;title=$entry.title})
  }
  foreach($done in [regex]::Matches($s,'return\s+status\s*==\s*xi.questStatus.QUEST_COMPLETED')){
   $part=($s.Substring($done.Index+$done.Length) -split 'check = function',2)[0]
   if($part -notmatch 'onTrade = function' -or $part -notmatch 'confirmTrade'){continue}
   $handler=[regex]::Match($part,'\[[''"]'+[regex]::Escape($name)+'[''"]\]\s*=')
   if(-not $handler.Success){continue}
   $part=$part.Substring($handler.Index+$handler.Length)
   $next=[regex]::Match($part,'\[[''"][^''"]+[''"]\]\s*=');if($next.Success){$part=$part.Substring(0,$next.Index)}
   $recipes=New-Object 'Collections.Generic.List[object]'
   foreach($trade in [regex]::Matches($part,'npcUtil.tradeHas(?:Exactly)?\(trade,\s*\{')){
    $body=Balanced $part ($trade.Index+$trade.Length-1) '{' '}'
    if(($body -replace 'xi.item.\w+|[\d\s{},]','') -ne ''){continue}
    $recipe=New-Object 'Collections.Generic.List[object]';$valid=$true
    foreach($m in [regex]::Matches($body,'\{\s*xi.item.(\w+)\s*,\s*(\d+)\s*\}')){
     if(-not $constants.ContainsKey($m.Groups[1].Value)){$valid=$false;break}
     $recipe.Add(@{id=$constants[$m.Groups[1].Value];count=[int]$m.Groups[2].Value})
    }
    $rest=$body -replace '\{\s*xi.item.\w+\s*,\s*\d+\s*\}',''
    foreach($m in [regex]::Matches($rest,'xi.item.(\w+)')){
     if(-not $constants.ContainsKey($m.Groups[1].Value)){$valid=$false;break}
     $recipe.Add(@{id=$constants[$m.Groups[1].Value];count=1})
    }
    if($valid -and $recipe.Count -gt 0){$recipes.Add(@($recipe.ToArray()))}
   }
   if($recipes.Count -gt 0){$repeat[$group+':'+$entry.id]=@($recipes.ToArray())}
  }
 }
 if($npcs.Count -lt 50 -or $items.Count -lt 50){throw 'Generated data coverage unexpectedly small; keeping previous data.'}
 $bundle=@{schema=1;sha=$Sha;time=[DateTimeOffset]::UtcNow.ToUnixTimeSeconds();npcs=@($npcs.ToArray());items=$items;repeatTurnins=$repeat;scanned=$scanned}
 $json=$bundle|ConvertTo-Json -Depth 20 -Compress
 [IO.File]::WriteAllText((Join-Path $cache 'source-data-candidate.json.tmp'),$json,[Text.UTF8Encoding]::new($false))
 Move-Item -LiteralPath (Join-Path $cache 'source-data-candidate.json.tmp') -Destination (Join-Path $cache 'source-data-candidate.json') -Force
 return @{npcs=$npcs.Count;items=$items.Count;recipes=$repeat.Count;scanned=$scanned}
}finally{
 Close-QuestTls
 # Explicit files only; this never recursively removes a computed directory.
 if($stage -and (Test-Path -LiteralPath $stage)){
  foreach($file in Get-ChildItem -LiteralPath $stage -File){Remove-Item -LiteralPath $file.FullName -Force}
  Remove-Item -LiteralPath $stage -Force
 }
}
