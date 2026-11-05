# Installeur de Tour de controle (Windows), depuis le depot GitHub prive des mises a jour.
# 1. Connexion a GitHub avec TON compte (un code a saisir sur github.com) : il faut avoir ete
#    invite sur le depot par la personne qui partage l'appli.
# 2. Telechargement de la derniere version, verification de son empreinte, installation dans
#    %LOCALAPPDATA%\Programs\Tour de controle, raccourcis Bureau et menu Demarrer.
# Aucun mot de passe ni jeton n'est enregistre par cet installeur : l'acces GitHub sert seulement
# au telechargement. Dans l'appli, connecte-toi une fois a GitHub pour recevoir les mises a jour.
# (Fichier en ASCII : PowerShell 5.1 lit les .ps1 sans BOM en ANSI.)

$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$ClientId = 'Ov23liBDVeFgmsICJVYN'
$Repo = 'Steven30878/tour-de-controle-maj'
$Agent = 'tour-de-controle-installeur'

function Fail($msg) {
  Write-Host ''
  Write-Host "ERREUR : $msg" -ForegroundColor Red
  exit 1
}

Write-Host ''
Write-Host '=== Installation de Tour de controle ===' -ForegroundColor Cyan
Write-Host ''
Write-Host 'Quelle edition ?'
Write-Host '  1) Edition cle API : pour tout le monde (tu utiliseras ta propre cle API Anthropic)'
Write-Host '  2) Edition perso   : reservee a la personne qui fait les mises a jour'
$choice = Read-Host 'Ton choix [1]'
$edition = if ($choice -eq '2') { 'perso' } else { 'vendable' }

# --- Connexion a GitHub (code a saisir sur github.com) -------------------------------------
try {
  $d = Invoke-RestMethod -Method Post -Uri 'https://github.com/login/device/code' -Headers @{ Accept = 'application/json'; 'User-Agent' = $Agent } -Body @{ client_id = $ClientId; scope = 'repo' }
} catch { Fail "GitHub ne repond pas ($($_.Exception.Message)). Verifie ta connexion internet." }
Write-Host ''
Write-Host 'Connexion a GitHub :' -ForegroundColor Cyan
Write-Host "  1. Sur la page qui s'ouvre ($($d.verification_uri)), saisis ce code :"
Write-Host ''
Write-Host "        $($d.user_code)" -ForegroundColor Yellow
Write-Host ''
Write-Host '  2. Autorise Tour de controle. Cette fenetre continue toute seule ensuite.'
try { Set-Clipboard -Value $d.user_code; Write-Host '  (Le code est deja copie : colle-le avec Ctrl+V.)' } catch {}
Start-Process $d.verification_uri

$token = $null
$wait = [Math]::Max(5, [int]$d.interval)
$deadline = (Get-Date).AddSeconds([int]$d.expires_in)
while (-not $token -and (Get-Date) -lt $deadline) {
  Start-Sleep -Seconds $wait
  try {
    $t = Invoke-RestMethod -Method Post -Uri 'https://github.com/login/oauth/access_token' -Headers @{ Accept = 'application/json'; 'User-Agent' = $Agent } -Body @{ client_id = $ClientId; device_code = $d.device_code; grant_type = 'urn:ietf:params:oauth:grant-type:device_code' }
  } catch { continue }
  if ($t.access_token) { $token = $t.access_token }
  elseif ($t.error -eq 'slow_down') { $wait += 5 }
  elseif ($t.error -ne 'authorization_pending') { Fail "connexion refusee ou expiree ($($t.error)). Relance l'installeur." }
}
if (-not $token) { Fail "le code a expire. Relance l'installeur." }
Write-Host 'Connecte a GitHub.' -ForegroundColor Green

$h = @{ Authorization = "Bearer $token"; Accept = 'application/vnd.github+json'; 'User-Agent' = $Agent; 'X-GitHub-Api-Version' = '2022-11-28' }
try {
  $rel = Invoke-RestMethod -Uri "https://api.github.com/repos/$Repo/releases/latest" -Headers $h
} catch {
  if ($_.Exception.Response -and [int]$_.Exception.Response.StatusCode -eq 404) { Fail "ton compte GitHub n'est pas invite sur le depot $Repo. Demande une invitation, accepte-la (mail de GitHub), puis relance." }
  Fail "lecture des versions impossible ($($_.Exception.Message))."
}

# Telecharge un fichier de la publication : GitHub renvoie vers son stockage, sans l'acces.
function Get-Asset($name, $dest) {
  $a = $rel.assets | Where-Object { $_.name -eq $name } | Select-Object -First 1
  if (-not $a) { Fail "$name absent de la version $($rel.tag_name)." }
  $req = [System.Net.HttpWebRequest]::Create($a.url)
  $req.AllowAutoRedirect = $false
  $req.UserAgent = $Agent
  $req.Accept = 'application/octet-stream'
  $req.Headers.Add('Authorization', "Bearer $token")
  $resp = $req.GetResponse()
  $location = $resp.Headers['Location']
  $resp.Close()
  $wc = New-Object System.Net.WebClient
  $wc.Headers.Add('User-Agent', $Agent)
  if ($location) { $wc.DownloadFile($location, $dest) } else { Fail "telechargement de $name refuse par GitHub." }
}

$work = Join-Path $env:TEMP 'tour-de-controle-installeur'
if (Test-Path $work) { Remove-Item $work -Recurse -Force }
New-Item -ItemType Directory -Path $work -Force | Out-Null

Write-Host "Version $($rel.tag_name) : lecture des informations..."
Get-Asset "manifest-$edition.json" (Join-Path $work 'manifest.json')
$m = Get-Content (Join-Path $work 'manifest.json') -Raw | ConvertFrom-Json
$zip = Join-Path $work $m.file
$sizeMo = [Math]::Round($m.size / 1MB)
Write-Host "Telechargement de $($m.file) ($sizeMo Mo), patiente quelques minutes..."
Get-Asset $m.file $zip

$hash = (Get-FileHash $zip -Algorithm SHA256).Hash.ToLower()
if ($hash -ne $m.sha256.ToLower()) { Fail 'le paquet telecharge est abime ou modifie (empreinte differente). Relance l''installeur.' }
Write-Host 'Paquet verifie.' -ForegroundColor Green

Write-Host 'Decompression...'
$unz = Join-Path $work 'paquet'
New-Item -ItemType Directory -Path $unz -Force | Out-Null
& (Join-Path $env:SystemRoot 'System32\tar.exe') -x -f $zip -C $unz
if ($LASTEXITCODE -ne 0) { Fail 'decompression impossible.' }

Write-Host 'Installation...'
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $unz 'installer.ps1')
if ($LASTEXITCODE -ne 0) { Fail 'installation impossible.' }
Remove-Item $work -Recurse -Force -ErrorAction SilentlyContinue

Write-Host ''
Write-Host "Tour de controle $($m.version) est installe." -ForegroundColor Green
Write-Host "Dans l'appli : Parametres > Version et mises a jour > Se connecter a GitHub, pour recevoir les mises a jour."
