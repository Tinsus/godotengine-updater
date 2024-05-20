#TODO: Godot_v3.5.1-stable_win64

$Script_path = Split-Path $MyInvocation.Mycommand.Path -Parent
$checkfile = "$Script_path\checkfile"

function removefile($path) {
	Remove-Item "$path" -recurse -force -ErrorAction SilentlyContinue
}

function newdir($path) {
	New-Item "$path" -ItemType Directory -ErrorAction SilentlyContinue
}

function nls($total) {
	for ($i = 0; $i -lt $total; $i++) {
		Write-Host " "
	}
}

function Get-IniContent($filePath) {
    $ini = @{}

    Switch -regex -file $FilePath {
		# Section
        "^\[(.+)\]" {
            $section = $matches[1]
            $ini[$section] = @{}
            $CommentCount = 0
        }
		# Comment
        "^(;.*)$" {
            $value = $matches[1]
            $CommentCount = $CommentCount + 1
            $name = "Comment" + $CommentCount
            $ini[$section][$name] = $value
        }
		# Key
        "(.+?)\s*=(.*)" {
            $name, $value = $matches[1..2]

			if (($value -eq "True") -or ($value -eq "False")) {
				$value = ($value -eq "True")
			}

            $ini[$section][$name] = $value
        }
    }

    return $ini
}

function Out-IniFile($InputObject, $FilePath) {
	$newlines = @()

    foreach ($i in $InputObject.keys) {
        if (!($($InputObject[$i].GetType().Name) -eq "Hashtable")) {
            #No Sections
            $newlines += "$i=$($InputObject[$i])"
        } else {
            #Sections
            $newlines += "[$i]"

            Foreach ($j in ($InputObject[$i].keys | Sort-Object)) {
                if ($j -match "^Comment[\d]+") {
                    $newlines += "$($InputObject[$i][$j])"
                } else {
                    $newlines += "$j=$($InputObject[$i][$j])"
                }
            }

            $newlines += ""
        }
    }

#	removefile $FilePath
    $newlines | Out-File $Filepath
}

#get dependencies
if (-not (Get-Module -ListAvailable -Name 7Zip4PowerShell)) {
	nls 6
	Write-Host "Please wait a moment - we need to add some dependencies. This is needed once only."
	nls 1

	if (-not (Get-PackageProvider -ListAvailable -Name NuGet)) {
		Install-PackageProvider -Name NuGet -Force -Scope CurrentUser
	}

    Install-Module -Name 7Zip4PowerShell -Scope CurrentUser -Force
}

#some "welcoming" text
Clear-Host
nls 6
Write-Host "Before we can do any nice stuff let us see what nice stuff is out there."
nls 1

#build config
if (Test-Path "$Script_path\godotengine.ini") {
	$conf = Get-IniContent "$Script_path\godotengine.ini"
} else {
	$conf = @{}
	$conf.version = @{}
}

# check githubs API restrictions and waits until it's possible again
Invoke-WebRequest "https://api.github.com/rate_limit" -OutFile "$Script_path\github.json"
$json = (Get-Content "$Script_path\github.json" -Raw) | ConvertFrom-Json
removefile "$Script_path\github.json"

if ($json.rate.remaining -lt 1) {
	nls 3
	Write-Host "No more updates possible due to API limitations by github.com :(" -ForegroundColor Red
	nls 3
	Write-Host "godot-stable will not been updated, so just keep going."

	Start-Process -FilePath "$Script_path\godot-stable.exe" -WorkingDirectory "$Script_path\" -ErrorAction SilentlyContinue

	Start-Sleep -Seconds 2
	exit
}

# place ._sc_ file to make godot self-contained (portable)

New-Item -ItemType File -Path ./._sc_ -Force


nls 2

# auto update this script itself (prepare the update to be done by the .bat file with the next start)
Write-Host "godotengine.bat " -NoNewline -ForegroundColor White
Write-Host "is " -NoNewline
Write-Host "updated " -NoNewline -ForegroundColor Green
Write-Host "every time"

removefile "$Script_path\godotengine.bat"
Invoke-WebRequest "https://github.com/Tinsus/godotengine-updater/raw/main/godotengine.bat" -OutFile "$Script_path/godotengine.bat"

# get godot version and download links
$checkurl = "https://api.github.com/repos/godotengine/godot/releases"
Invoke-WebRequest "$checkurl" -OutFile "$checkfile"
$json = (Get-Content "$checkfile" -Raw) | ConvertFrom-Json
removefile "$checkfile"

$name = 0
$download = 0
$size = 0
$new = 0

$json[0].assets | foreach {
	if (
		($_.browser_download_url -like "*win64*") -and
		($_.browser_download_url -like "*.zip") -and
		-not (($_.browser_download_url -like "*mono"))
	) {
		$download = $_.browser_download_url
		$size = $_.size
		$new = $_.created_at
		$name = $($_.name).replace(".zip", "")
	}
}

if ($download -eq 0) {
	nls 5
	Write-Host "No download for windows could be found." -ForegroundColor Red
	nls 2
	Write-Host "If this seems to be an error report it at: https://github.com/Tinsus/godotengine-updater/issues" -ForegroundColor Yellow

	Start-Sleep -Seconds 2
} else {
	if (
		($conf.version.godot -eq $null) -or
		($conf.version.godot -ne $new) -or
		(-not (Test-Path "$Script_path\Godot-stable.exe"))
	) {
		Write-Host "Godot " -NoNewline -ForegroundColor White
		Write-Host "gets an " -NoNewline
		Write-Host "update" -ForegroundColor Green

		#download godot
		nls 1
		Write-Host "Download is running. Please wait, until the Bytes downloaded reach " -NoNewline
		Write-Host $size -ForegroundColor Yellow

		Invoke-WebRequest $download -OutFile "$checkfile.zip"

		Write-Host "Download finished" -ForegroundColor Green

		#"installing" Godot
		nls 1
		Write-Host "Extracting the downloaded files"

		removefile "$Script_path\unzipped\"
		newdir "$Script_path\unzipped\"

		Expand-Archive -Path "$checkfile.zip" -DestinationPath "$Script_path\unzipped\" -Force

		removefile "$Script_path\Godot-stable.exe"
		Move-Item "$Script_path\unzipped\$name" "$Script_path\Godot-stable.exe"
		Move-Item "$checkfile.zip" "$Script_path\$name.zip"
		removefile "$Script_path\unzipped\"

		Write-Host "Update finished" -ForegroundColor Green

		$conf.version.godot = $new
		Out-IniFile -InputObject $conf -FilePath "$Script_path\godotengine.ini"
	} else {
		Write-Host "Godot " -NoNewline -ForegroundColor White
		Write-Host "is " -NoNewline
		Write-Host "up to date" -ForegroundColor White
	}
}

# done with updating
Start-Process -FilePath "$Script_path\Godot-stable.exe" -WorkingDirectory "$Script_path" -ErrorAction SilentlyContinue

nls 1
Write-Host "I have other stuff to do"

Start-Sleep -Seconds 18
exit
