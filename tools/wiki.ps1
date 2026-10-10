param([Parameter(Mandatory=$true)][string]$Title,[Parameter(Mandatory=$true)][string]$Key,[string]$FixtureHtml,[switch]$QuestReference,[string]$BgTitle,[switch]$FixtureBg)
$ErrorActionPreference='Stop'
if ($Key -notmatch '^[a-f0-9]+$') { exit 1 }
$cache=Join-Path (Split-Path $PSScriptRoot -Parent) 'cache'
[IO.Directory]::CreateDirectory($cache) | Out-Null
$dest=Join-Path $cache ($Key+'.json')
$base='https://wiki.phoenix-xi.com'
[Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12
. (Join-Path $PSScriptRoot 'network.ps1')
function Plain([string]$s) {
    $s=[regex]::Replace($s,'(?s)<!--.*?-->','')
    $s=[regex]::Replace($s,'(?is)<span class="mw-editsection".*?</span></span>','')
    $s=[regex]::Replace($s,'(?is)<(script|style)\b[^>]*>.*?</\1>','')
    $s=[regex]::Replace($s,'(?is)<br\s*/?>|</(?:p|div|tr|li|h[1-6])>',''+"`n")
    $s=[regex]::Replace($s,'(?is)</t[dh]>','  ')
    $s=[regex]::Replace($s,'<[^>]+>','')
    $s=[Net.WebUtility]::HtmlDecode($s)
    $s=[regex]::Replace($s,'[ \t]+',' ')
    $s=[regex]::Replace($s,'\n\s*\n+',"`n`n")
    return $s.Trim()
}
try {
    $name=[Uri]::UnescapeDataString($Title)
    $source='Phoenix'
    $phoenixError=$null
    try {
    if ($FixtureBg) { throw 'No matching Phoenix wiki page.' }
    if($FixtureHtml){
        $data=@{parse=@{title=$name;text=@{'*'=[IO.File]::ReadAllText($FixtureHtml)}}}
    }else{
        $data=Fetch ($base+'/api.php?action=parse&redirects=1&prop=text&format=json&page='+[Uri]::EscapeDataString($name))
    }
    if ($data.error) {
        $search=Fetch ($base+'/api.php?action=query&list=search&srlimit=5&format=json&srsearch='+[Uri]::EscapeDataString($name))
        if (-not $search.query.search.Count) { throw 'No matching Phoenix wiki page. Use the wiki search button.' }
        if ($QuestReference -or $BgTitle) {
            $normalized=($name.ToLowerInvariant() -replace '[^a-z0-9]','')
            $match=$search.query.search | Where-Object { ($_.title.ToLowerInvariant() -replace '[^a-z0-9]','') -eq $normalized } | Select-Object -First 1
            if (-not $match) { throw 'No exact Phoenix wiki page for this quest yet.' }
            $name=$match.title
        } else { $name=$search.query.search[0].title }
        $data=Fetch ($base+'/api.php?action=parse&redirects=1&prop=text&format=json&page='+[Uri]::EscapeDataString($name))
    }
    if ($data.error) { throw $data.error.info }
    } catch {
        $phoenixError=$_.Exception.Message
        if (-not $BgTitle) { throw }
        $source='BG';$base='https://www.bg-wiki.com'
        $name=[Uri]::UnescapeDataString($BgTitle)
        if ($FixtureBg -and $FixtureHtml) {
            $data=@{parse=@{title=$name;text=@{'*'=[IO.File]::ReadAllText($FixtureHtml)}}}
        } else {
            $data=Fetch ($base+'/api.php?action=parse&redirects=1&prop=text&format=json&page='+[Uri]::EscapeDataString($name))
            if ($data.error) {
                $search=Fetch ($base+'/api.php?action=query&list=search&srlimit=10&format=json&srsearch='+[Uri]::EscapeDataString($name))
                $normalized=($name.ToLowerInvariant() -replace '[^a-z0-9]','')
                $match=$search.query.search | Where-Object { ($_.title.ToLowerInvariant() -replace '[^a-z0-9]','') -eq $normalized } | Select-Object -First 1
                if (-not $match) { throw 'No matching Phoenix or BG wiki page.' }
                $data=Fetch ($base+'/api.php?action=parse&redirects=1&prop=text&format=json&page='+[Uri]::EscapeDataString($match.title))
            }
            if ($data.error) { throw $data.error.info }
        }
    }
    $html=[string]$data.parse.text.'*'
    $item=$null
    if($html -match 'pxwiki-infobox-item') {
        $fields=@{}
        foreach($row in [regex]::Matches($html,'(?is)<div class="pxwiki-infobox-label">(.*?)</div><div class="pxwiki-infobox-value">(.*?)</div>')) {
            $fields[(Plain $row.Groups[1].Value)]=(Plain $row.Groups[2].Value)
        }
        $description=Plain ([regex]::Match($html,'(?is)<div class="pxwiki-infobox-description">(.*?)</div>').Groups[1].Value)
        $item=@{description=$description;fields=$fields;rare=($html -match 'pxwiki-badge-rare');ex=($html -match 'pxwiki-badge-ex')}
    }
    $links=@();$seen=@{}
    foreach($match in [regex]::Matches($html,'(?is)<a\b[^>]*href="([^"]+)"[^>]*>(.*?)</a>')) {
        $href=[Net.WebUtility]::HtmlDecode($match.Groups[1].Value)
        $label=Plain $match.Groups[2].Value
        if (-not $label -or $label.Length -gt 100 -or $href.StartsWith('#')) { continue }
        if ($href.StartsWith($base+'/')) { $href=$href.Substring($base.Length) }
        if ($source -eq 'BG' -and $href.StartsWith('/ffxi/')) { $href=$href.Substring(5) }
        if (-not $href.StartsWith('/') -or $href.StartsWith('//') -or $href -match '^/(api\.php|index\.php|Special:|Category:|Template:|Help:)') { continue }
        $target=[Uri]::UnescapeDataString(($href.TrimStart('/') -split '#')[0]).Replace('_',' ')
        if ($target -match '^(File:|Image:)') { continue }
        if ($seen.ContainsKey($target)) {
            $entry=$seen[$target]
            if ($entry.label -ne $label -and $entry.aliases -notcontains $label) { $entry.aliases+=@($label) }
            continue
        }
        $entry=@{title=$target;label=$label;aliases=@()};$seen[$target]=$entry
        $links+= $entry
        
    }
    # Keep the item infobox together for the hover card, when one exists.
    $box=[regex]::Match($html,'(?is)<table\b[^>]*class="[^"]*(?:infobox|item-info|itembox)[^"]*"[^>]*>.*?</table>')
    $preview=if($box.Success){Plain $box.Value}else{(Plain $html)}
    if($preview.Length -gt 1800){$preview=$preview.Substring(0,1800)+'...'}
    # Preserve caption-to-map associations and use the original image, not its thumbnail.
    $captions=@{}
    foreach($figure in [regex]::Matches($html,'(?is)<figure\b[^>]*>.*?</figure>')) {
        $srcMatch=[regex]::Match($figure.Value,'src="([^"]+)"')
        $captionMatch=[regex]::Match($figure.Value,'(?is)<figcaption[^>]*>(.*?)</figcaption>')
        if($srcMatch.Success -and $captionMatch.Success){$captions[$srcMatch.Groups[1].Value]=(Plain $captionMatch.Groups[1].Value)}
    }
    $images=@();$imgseen=@{}
    foreach($match in [regex]::Matches($html,'(?is)<img\b[^>]*src="([^"]+)"[^>]*>')) {
        $rawSrc=$match.Groups[1].Value
        $caption=$captions[$rawSrc]
        $src=[Net.WebUtility]::HtmlDecode($rawSrc)
        $src=[regex]::Replace($src,'/images/thumb/(.+)/[^/]+$','/images/$1')
        if($src.StartsWith('//')){$src='https:'+$src}
        elseif($src.StartsWith('/')){$src=$base+$src}
        if($src -notmatch '^https://(?:wiki\.phoenix-xi\.com/|static\.ffxiah\.com/images/|(?:www\.)?bg-wiki\.com/images/)' -or $src -notmatch '\.(png|jpe?g)(?:\?|$)' -or $imgseen.ContainsKey($src)){continue}
        $imgseen[$src]=$true
        $alt=[regex]::Match($match.Value,'alt="([^"]*)"').Groups[1].Value
        $ext=[regex]::Match($src,'\.(png|jpe?g)(?:\?|$)').Groups[1].Value
        $file=$Key+'-'+$images.Count+'.'+$ext
        try {
            if(-not $FixtureHtml){Download-QuestFile $src (Join-Path $cache $file)}
            $label=if($caption){$caption}else{[Net.WebUtility]::HtmlDecode($alt)}
            $images+=@{file=$file;label=$label;url=$src}
            if($caption){$links+=@{title=('Map image: '+$file);label=$caption;aliases=@()}}
        } catch { }
        if($images.Count -ge 6){break}
    }
    $result=@{linkSchema=2;title=$data.parse.title;text=(Plain $html);preview=$preview;item=$item;links=@($links);images=@($images);url=$base+'/'+[Uri]::EscapeDataString($data.parse.title.Replace(' ','_'));time=[DateTimeOffset]::UtcNow.ToUnixTimeSeconds()}
    $result.source=$source;$result.fallbackSchema=1;$result.mapSchema=1
    if ($source -eq 'BG') {
        $result.url=$base+'/ffxi/'+[Uri]::EscapeDataString($data.parse.title.Replace(' ','_'))
        $result.text += "`n`nSource: BG-Wiki contributors. Temporary fallback; retail guide details may differ from Phoenix. " + $result.url
    }
} catch { $result=@{fallbackSchema=1;time=[DateTimeOffset]::UtcNow.ToUnixTimeSeconds();error=$_.Exception.Message;title=$Title;links=@();images=@()} }
$json=$result | ConvertTo-Json -Depth 8 -Compress
$temp=$dest+'.tmp'
[IO.File]::WriteAllText($temp,$json,(New-Object Text.UTF8Encoding($false)))
Move-Item -LiteralPath $temp -Destination $dest -Force
Close-QuestTls
