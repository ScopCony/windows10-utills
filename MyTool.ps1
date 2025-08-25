# Generowanie logo
npx oh-my-logo@latest "My Tool" sunset --filled
npx oh-my-logo@latest "by ScopCony" sunset --filled

# SystemDashboard - Monitoring System Status
Write-Host ""
Write-Host "                    by ScopCony 2025 $([char]0x00A9)                       " -ForegroundColor DarkCyan
Write-Host ""
Write-Host ""

# region Konfiguracja protokołu sieciowego
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12
# endregion

# region Wymuszenie kodowania
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::InputEncoding = [System.Text.Encoding]::UTF8
# endregion

# region Definicje kolorów
$colors = @{
    Error       = "Red"
    Success     = "Green"
    Highlight   = "Blue"
    Header      = "DarkRed"
    Info        = "White"
    DefaultText = "Gray"
}
# endregion

# region Konfiguracja
$githubRepoUrl = "https://raw.githubusercontent.com/ScopCony/windows10-utills/main"
# endregion

# Pobieranie danych systemowych
$currentUser = [Environment]::UserName + "@" + [Environment]::MachineName
$operatingSystem = (Get-CimInstance Win32_OperatingSystem).Caption
$currentTime = Get-Date -Format "dd.MM.yyyy HH:mm:ss"
$powerShellVersion = $PSVersionTable.PSVersion.Major.ToString() + "." + $PSVersionTable.PSVersion.Minor.ToString()

# Informacje o sprzęcie
$processorInfo = (Get-CimInstance Win32_Processor).Name
$videoCard = (Get-CimInstance Win32_VideoController | Where-Object {$_.Name -notlike "*Basic*"}).Name | Select-Object -First 1
$networkAdapter = (Get-CimInstance Win32_NetworkAdapterConfiguration | Where-Object {$_.IPAddress -ne $null}).IPAddress[0]

# Wykorzystanie procesora
$cpuLoad = [math]::Round((Get-Counter "\Processor(_Total)\% Processor Time").CounterSamples.CookedValue, 1)

# Pamięć RAM (tylko wielkość)
$ramInfo = Get-CimInstance Win32_ComputerSystem
$totalRAM = [math]::Round($ramInfo.TotalPhysicalMemory / 1GB, 1)

# Dyski
$diskList = Get-CimInstance Win32_LogicalDisk | Where-Object {$_.DriveType -eq 3}

# Funkcja do wyrównywania tekstu
function Format-TableLine {
    param([string]$text, [int]$width = 48)
    while ($text.Length -lt $width) { $text += " " }
    return $text
}

# Wyświetlanie dashboardu
Write-Host "+===============[ OVERVIEW ]================+" -ForegroundColor Cyan

$userLine = "| User: " + $currentUser
Write-Host (Format-TableLine $userLine) -NoNewline
Write-Host "|"

$osLine = "| System: " + $operatingSystem
Write-Host (Format-TableLine $osLine) -NoNewline
Write-Host "|"

$timeLine = "| Date: " + $currentTime
Write-Host (Format-TableLine $timeLine) -NoNewline
Write-Host "|"

$psLine = "| PowerShell: " + $powerShellVersion
Write-Host (Format-TableLine $psLine) -NoNewline
Write-Host "|"

Write-Host "+==============[ HARDWARE ]================+" -ForegroundColor Cyan

$cpuLine = "| Processor: " + $processorInfo.Substring(0, [Math]::Min(25, $processorInfo.Length))
Write-Host (Format-TableLine $cpuLine) -NoNewline
Write-Host "|"

$cpuUsageLine = "| CPU Usage: " + $cpuLoad + "%"
if ($cpuLoad -gt 80) {
    Write-Host (Format-TableLine $cpuUsageLine) -NoNewline -ForegroundColor Red
} elseif ($cpuLoad -gt 60) {
    Write-Host (Format-TableLine $cpuUsageLine) -NoNewline -ForegroundColor Yellow
} else {
    Write-Host (Format-TableLine $cpuUsageLine) -NoNewline -ForegroundColor Green
}
Write-Host "|"

if ($videoCard) {
    $gpuLine = "| Graphics: " + $videoCard.Substring(0, [Math]::Min(25, $videoCard.Length))
    Write-Host (Format-TableLine $gpuLine) -NoNewline
    Write-Host "|"
}

$memoryLine = "| RAM: " + $totalRAM + "GB"
Write-Host (Format-TableLine $memoryLine) -NoNewline -ForegroundColor Green
Write-Host "|"

Write-Host "+===============[ NETWORK ]================+" -ForegroundColor Cyan

$ipLine = "| IP Address: " + $networkAdapter
Write-Host (Format-TableLine $ipLine) -NoNewline
Write-Host "|"

Write-Host "+==============[ STORAGE ]================+" -ForegroundColor Cyan

foreach ($disk in $diskList) {
    $totalSize = [math]::Round($disk.Size / 1GB, 0)
    $freeSpace = [math]::Round($disk.FreeSpace / 1GB, 0)
    $usedSpace = $totalSize - $freeSpace
    $diskPercent = [math]::Round(($usedSpace / $totalSize) * 100, 1)
    
    $diskColor = "Green"
    $diskStatus = ""
    if ($diskPercent -ge 90) { 
        $diskColor = "Red"
        $diskStatus = " [CRITICAL]" 
    }
    elseif ($diskPercent -ge 75) { 
        $diskColor = "Yellow"
        $diskStatus = " [WARNING]" 
    }

    $diskLine = "| Drive " + $disk.DeviceID + " " + $usedSpace + "GB / " + $totalSize + "GB (" + $diskPercent + "%)" + $diskStatus
    Write-Host (Format-TableLine $diskLine) -NoNewline -ForegroundColor $diskColor
    Write-Host "|"
}

Write-Host "+==========================================+" -ForegroundColor Cyan
Write-Host ""

# region Funkcje pomocnicze dla zarządzania programami

function Check-Admin {
    $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    if (-not $isAdmin) {
        Write-Host "Ten skrypt musi być uruchomiony z uprawnieniami administratora." -ForegroundColor $colors.Error
        Write-Host "Proszę zamknij to okno i uruchom ponownie PowerShell jako administrator."
        Read-Host "Naciśnij Enter, aby zamknąć..."
        exit
    }
}

function Check-Chocolatey {
    $chocoExists = Get-Command choco -ErrorAction SilentlyContinue
    if (-not $chocoExists) {
        Write-Host "Narzędzie Chocolatey nie zostało znalezione." -ForegroundColor $colors.Highlight
        $installChoice = Read-Host "Czy chcesz je teraz zainstalować? (y/n)"
        if ($installChoice -eq 'y') {
            Write-Host "Instalowanie Chocolatey..." -ForegroundColor $colors.Success
            try {
                Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
                Write-Host "Chocolatey został pomyślnie zainstalowany. Uruchom skrypt ponownie." -ForegroundColor $colors.Success
            }
            catch {
                Write-Host "Wystąpił błąd podczas instalacji Chocolatey." -ForegroundColor $colors.Error
                Write-Host "Szczegóły błędu: $($_.Exception.Message)"
            }
            Read-Host "Naciśnij Enter, aby zamknąć..."
            exit
        }
        else {
            Write-Host "Instalacja programów nie będzie możliwa bez Chocolatey. Zamykanie skryptu." -ForegroundColor $colors.Error
            Read-Host "Naciśnij Enter, aby zamknąć..."
            exit
        }
    }
    else {
        Write-Host "Znaleziono zainstalowane narzędzie Chocolatey." -ForegroundColor $colors.Success
    }
}

function Get-JsonData($fileName) {
    $url = "$($githubRepoUrl)/config/$($fileName)"
    try {
        Write-Host "Pobieram dane z $url..." -ForegroundColor $colors.Info
        $data = Invoke-RestMethod -Uri $url
        return $data
    }
    catch {
        Write-Host "Błąd podczas pobierania pliku $fileName." -ForegroundColor $colors.Error
        Write-Host "Szczegóły błędu: $($_.Exception.Message)"
        return $null
    }
}

function Show-AppsMenu($appsData) {
    Write-Host "`n==== Zarządzanie programami ====`n" -ForegroundColor $colors.Header
    
    $count = 1
    foreach ($category in $appsData) {
        Write-Host "`n---- $($category.Category) ----" -ForegroundColor $colors.Header
        
        foreach ($app in $category.Apps) {
            Write-Host ("{0,3}. " -f $count) -ForegroundColor $colors.Success -NoNewline
            Write-Host $app.Name -ForegroundColor $colors.Highlight -NoNewline
            Write-Host " - $($app.Description)" -ForegroundColor $colors.DefaultText
            $count++
        }
    }

    Write-Host "`n" -NoNewline
    Write-Host "s" -ForegroundColor $colors.Success -NoNewline
    Write-Host " - Wyszukaj program (z autouzupełnianiem TAB)"
    Write-Host "q" -ForegroundColor $colors.Success -NoNewline
    Write-Host " - Powrót do głównego menu`n"
    $choice = Read-Host "Wybierz numer programu, 's' aby wyszukać, lub numery po przecinku (np. 1,5,8)"
    return $choice
}

function Show-SearchResults($foundApps, $searchTerm) {
    if ($foundApps.Count -eq 0) {
        Write-Host "Brak wyników dla: '$searchTerm'" -ForegroundColor $colors.Error
        return
    }

    Write-Host "`nZnaleziono $($foundApps.Count) programów dla: '$searchTerm'`n" -ForegroundColor $colors.Success

    for ($i = 0; $i -lt $foundApps.Count; $i++) {
        $foundApp = $foundApps[$i]
        Write-Host ("{0,3}. " -f $foundApp.OriginalIndex) -ForegroundColor $colors.Success -NoNewline
        Write-Host $foundApp.App.Name -ForegroundColor $colors.Highlight -NoNewline
        Write-Host " - $($foundApp.App.Description)" -ForegroundColor $colors.DefaultText
    }
}

function Get-AutocompleteSuggestions($allApps, $searchTerm) {
    $suggestions = [System.Collections.Generic.List[string]]::new()
    
    if ([string]::IsNullOrEmpty($searchTerm)) {
        $firstLetters = @{}
        foreach ($app in $allApps) {
            if ($app.Name.Length -gt 0) {
                $firstLetter = $app.Name.Substring(0,1).ToUpper()
                $firstLetters[$firstLetter] = $true
            }
        }
        foreach ($letter in ($firstLetters.Keys | Sort-Object)) {
            $suggestions.Add($letter)
        }
    }
    else {
        $matchingApps = [System.Collections.Generic.List[string]]::new()
        foreach ($app in $allApps) {
            if ($app.Name -like "$searchTerm*") {
                $matchingApps.Add($app.Name)
            }
        }
        
        $sortedApps = $matchingApps | Sort-Object
        if ($null -ne $sortedApps) {
            foreach ($appName in $sortedApps) {
                $suggestions.Add($appName)
            }
        }
    }
    
    return $suggestions
}

function Show-AutocompleteHints($allApps, $searchTerm) {
    if ([string]::IsNullOrEmpty($searchTerm)) {
        return
    }
    
    $hints = Get-AutocompleteSuggestions -allApps $allApps -searchTerm $searchTerm
    if ($hints.Count -gt 0) {
        Write-Host "`nPropozycje (TAB): " -ForegroundColor $colors.Info -NoNewline
        $displayHints = $hints | Select-Object -First 5
        $hintText = $displayHints -join ", "
        if ($hints.Count -gt 5) {
            $hintText += "..."
        }
        Write-Host $hintText -ForegroundColor $colors.DefaultText
    }
}

function Find-CommonPrefix($suggestions, $currentTerm) {
    if ($suggestions.Count -eq 0) {
        return $currentTerm
    }
    
    if ($suggestions.Count -eq 1) {
        return $suggestions[0]
    }
    
    $shortest = $suggestions[0]
    foreach ($suggestion in $suggestions) {
        if ($suggestion.Length -lt $shortest.Length) {
            $shortest = $suggestion
        }
    }
    
    $commonPrefix = ""
    for ($i = 0; $i -lt $shortest.Length; $i++) {
        $char = $shortest[$i]
        $allMatch = $true
        
        foreach ($suggestion in $suggestions) {
            if ($suggestion[$i] -ne $char) {
                $allMatch = $false
                break
            }
        }
        
        if ($allMatch) {
            $commonPrefix += $char
        }
        else {
            break
        }
    }
    
    return $commonPrefix
}

function Search-Apps-Interactive($allApps) {
    Write-Host "`n==== Interaktywne wyszukiwanie programów ====`n" -ForegroundColor $colors.Header
    Write-Host "Sterowanie:" -ForegroundColor $colors.Info
    Write-Host "- Wpisz litery: wyszukiwanie" -ForegroundColor $colors.DefaultText
    Write-Host "- Wpisz numer: wybierz program bezpośrednio" -ForegroundColor $colors.DefaultText
    Write-Host "- TAB: autouzupełnienie do wspólnego prefiksu" -ForegroundColor $colors.DefaultText
    Write-Host "- BACKSPACE: usuń ostatni znak" -ForegroundColor $colors.DefaultText
    Write-Host "- ENTER: wybierz więcej programów z wyników" -ForegroundColor $colors.DefaultText
    Write-Host "- ESC: wyczyść wyszukiwanie" -ForegroundColor $colors.DefaultText
    Write-Host "- Q lub CTRL+C: powrót do menu`n" -ForegroundColor $colors.DefaultText

    $searchTerm = ""
    $foundApps = [System.Collections.Generic.List[object]]::new()
    $numberInput = ""

    while ($true) {
        Clear-Host
        Write-Host "`n==== Interaktywne wyszukiwanie programów ====`n" -ForegroundColor $colors.Header
        
        if ([string]::IsNullOrEmpty($searchTerm)) {
            Write-Host "Wpisz pierwsze litery nazwy programu..." -ForegroundColor $colors.Info
        } else {
            Write-Host "Wyszukiwanie: '$searchTerm'" -ForegroundColor $colors.Highlight
            Show-SearchResults -foundApps $foundApps -searchTerm $searchTerm
            Show-AutocompleteHints -allApps $allApps -searchTerm $searchTerm
        }
        
        if (-not [string]::IsNullOrEmpty($numberInput)) {
            Write-Host "`nWpisywany numer: $numberInput" -ForegroundColor $colors.Highlight
        }
        
        Write-Host "`nWpisz znak (TAB=uzupełnij, ENTER=wybierz więcej, ESC=wyczyść, Q=wyjście):" -ForegroundColor $colors.Info
        
        $key = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        
        switch ($key.VirtualKeyCode) {
            9 { # TAB
                $numberInput = ""
                $matchingApps = [System.Collections.Generic.List[string]]::new()
                foreach ($app in $allApps) {
                    if ($app.Name -like "$searchTerm*") {
                        $matchingApps.Add($app.Name)
                    }
                }
                
                if ($matchingApps.Count -eq 0) {
                    continue
                }
                elseif ($matchingApps.Count -eq 1) {
                    $searchTerm = $matchingApps[0]
                }
                else {
                    $commonPrefix = Find-CommonPrefix -suggestions $matchingApps -currentTerm $searchTerm
                    
                    if ($commonPrefix.Length -gt $searchTerm.Length) {
                        $searchTerm = $commonPrefix
                    }
                }
                
                $foundApps.Clear()
                if (-not [string]::IsNullOrEmpty($searchTerm)) {
                    for ($i = 0; $i -lt $allApps.Count; $i++) {
                        $app = $allApps[$i]
                        if ($app.Name -like "$searchTerm*") {
                            $foundApps.Add(@{
                                App = $app
                                OriginalIndex = $i + 1
                            })
                        }
                    }
                }
            }
            8 { # BACKSPACE
                if (-not [string]::IsNullOrEmpty($numberInput)) {
                    if ($numberInput.Length -gt 1) {
                        $numberInput = $numberInput.Substring(0, $numberInput.Length - 1)
                    } else {
                        $numberInput = ""
                    }
                }
                elseif ($searchTerm.Length -gt 0) {
                    $searchTerm = $searchTerm.Substring(0, $searchTerm.Length - 1)
                    $foundApps.Clear()
                    if (-not [string]::IsNullOrEmpty($searchTerm)) {
                        for ($i = 0; $i -lt $allApps.Count; $i++) {
                            $app = $allApps[$i]
                            if ($app.Name -like "$searchTerm*") {
                                $foundApps.Add(@{
                                    App = $app
                                    OriginalIndex = $i + 1
                                })
                            }
                        }
                    }
                }
            }
            13 { # ENTER
                if (-not [string]::IsNullOrEmpty($numberInput)) {
                    $inputNumber = [int]$numberInput
                    foreach ($foundApp in $foundApps) {
                        if ($foundApp.OriginalIndex -eq $inputNumber) {
                            return $inputNumber.ToString()
                        }
                    }
                    Write-Host "`nNumer '$numberInput' nie ma w wynikach wyszukiwania." -ForegroundColor $colors.Error
                    $numberInput = ""
                    Start-Sleep -Milliseconds 1000
                    continue
                }
                
                if ($foundApps.Count -eq 0) {
                    Write-Host "`nBrak wyników do wyboru. Wpisz fragment nazwy programu." -ForegroundColor $colors.Error
                    Start-Sleep -Milliseconds 1000
                    continue
                }
                
                Write-Host "`nWybierz oryginalne numery z wyników (np. 74,75,213):" -ForegroundColor $colors.Highlight
                $choice = Read-Host
                
                if ([string]::IsNullOrWhiteSpace($choice)) {
                    continue
                }

                $searchChoices = $choice.Split(',')
                $originalNumbers = [System.Collections.Generic.List[string]]::new()
                
                foreach ($searchChoice in $searchChoices) {
                    $trimmedChoice = $searchChoice.Trim()
                    if ($trimmedChoice -match "^\d+$") {
                        $inputNumber = [int]$trimmedChoice
                        $foundMatch = $false
                        foreach ($foundApp in $foundApps) {
                            if ($foundApp.OriginalIndex -eq $inputNumber) {
                                $originalNumbers.Add($inputNumber.ToString())
                                $foundMatch = $true
                                break
                            }
                        }
                        if (-not $foundMatch) {
                            Write-Host "Pominięto numer '$($trimmedChoice)' - nie ma go w wynikach wyszukiwania." -ForegroundColor $colors.Error
                        }
                    }
                    else {
                        Write-Host "Pominięto nieprawidłowy numer: '$($trimmedChoice)'" -ForegroundColor $colors.Error
                    }
                }

                if ($originalNumbers.Count -gt 0) {
                    return ($originalNumbers -join ',')
                }
                else {
                    Write-Host "Nie wybrano żadnych prawidłowych programów z wyników." -ForegroundColor $colors.Error
                    Read-Host "Naciśnij Enter, aby kontynuować..."
                }
            }
            27 { # ESC
                $searchTerm = ""
                $foundApps.Clear()
                $numberInput = ""
            }
            81 { # Q
                return $null
            }
            3 { # CTRL+C
                return $null
            }
            default {
                $char = $key.Character
                if ($char -match '[0-9]') {
                    if ($foundApps.Count -gt 0) {
                        $numberInput += $char
                        
                        if ($numberInput -match "^\d+$") {
                            $potentialNumber = [int]$numberInput
                            foreach ($foundApp in $foundApps) {
                                if ($foundApp.OriginalIndex -eq $potentialNumber) {
                                    return $potentialNumber.ToString()
                                }
                            }
                        }
                    } else {
                        $searchTerm += $char
                        $numberInput = ""
                        
                        $foundApps.Clear()
                        for ($i = 0; $i -lt $allApps.Count; $i++) {
                            $app = $allApps[$i]
                            if ($app.Name -like "$searchTerm*") {
                                $foundApps.Add(@{
                                    App = $app
                                    OriginalIndex = $i + 1
                                })
                            }
                        }
                    }
                }
                elseif ($char -match '[a-zA-Z\s\-\.]') {
                    $numberInput = ""
                    $searchTerm += $char
                    
                    $foundApps.Clear()
                    for ($i = 0; $i -lt $allApps.Count; $i++) {
                        $app = $allApps[$i]
                        if ($app.Name -like "$searchTerm*") {
                            $foundApps.Add(@{
                                App = $app
                                OriginalIndex = $i + 1
                            })
                        }
                    }
                }
            }
        }
    }
}

# NOWA FUNKCJA dla Registry Tweaks
function Set-RegistryTweak {
    param(
        [string]$Path,
        [string]$ValueName,
        [int]$Value
    )
    
    try {
        if (-not (Test-Path $Path)) {
            New-Item -Path $Path -Force | Out-Null
            Write-Host "Utworzono ścieżkę rejestru: $Path" -ForegroundColor $colors.Info
        }
        
        Set-ItemProperty -Path $Path -Name $ValueName -Value $Value -Type DWord
        Write-Host "Ustawiono $ValueName = $Value w $Path" -ForegroundColor $colors.Success
        return $true
    }
    catch {
        Write-Host "Błąd podczas modyfikacji rejestru: $($_.Exception.Message)" -ForegroundColor $colors.Error
        return $false
    }
}

# ZMIENIONA FUNKCJA Show-FeaturesMenu
function Show-FeaturesMenu($features) {
    Write-Host "`n==== Zarządzanie funkcjami Windows i System Tweaks ====`n" -ForegroundColor $colors.Header
    for ($i = 0; $i -lt $features.Count; $i++) {
        $feature = $features[$i]
        
        if ($feature.Type -eq "WindowsFeature") {
            $status = (Get-WindowsOptionalFeature -Online -FeatureName $feature.FeatureName).State
        }
        elseif ($feature.Type -eq "Registry") {
            try {
                $currentValue = Get-ItemProperty -Path $feature.FeatureName -Name $feature.ValueName -ErrorAction SilentlyContinue
                if ($null -ne $currentValue) {
                    $status = if ($currentValue.($feature.ValueName) -eq $feature.EnableValue) { "Enabled" } else { "Disabled" }
                } else {
                    $status = "Not Set"
                }
            }
            catch {
                $status = "Unknown"
            }
        }
        
        Write-Host ("{0,3}. {1,-40} - {2} (Status: {3})" -f ($i + 1), $feature.Name, $feature.Description, $status)
    }
    Write-Host "`n" -NoNewline
    Write-Host "q" -ForegroundColor $colors.Success -NoNewline
    Write-Host " - Powrót do głównego menu`n"
    $choice = Read-Host "Wybierz numer, aby włączyć/wyłączyć funkcję"
    return $choice
}

function Invoke-ChocoCommand {
    param(
        [string]$Command,
        [string]$PackageId,
        [string]$InstallPath = ""
    )
    
    $chocoArgs = @($Command, $PackageId, "-y")
    if ($Command -eq "install" -and -not [string]::IsNullOrEmpty($InstallPath)) {
        $chocoArgs += "--install-directory=`"$InstallPath`""
        Write-Host "Uwaga: Nie wszystkie pakiety Chocolatey wspierają niestandardową ścieżkę instalacji." -ForegroundColor $colors.Highlight
    }

    Write-Host "Wykonywanie polecenia: choco $($chocoArgs -join ' ')" -ForegroundColor $colors.Info
    try {
        $process = Start-Process choco -ArgumentList $chocoArgs -Wait -PassThru -NoNewWindow
        if ($process.ExitCode -eq 0) {
            Write-Host "Polecenie wykonane pomyślnie." -ForegroundColor $colors.Success
        }
        else {
            Write-Host "Polecenie zakończyło się błędem (kod wyjścia: $($process.ExitCode))." -ForegroundColor $colors.Error
        }
    }
    catch {
        Write-Host "Wystąpił krytyczny błąd podczas wykonywania polecenia choco." -ForegroundColor $colors.Error
        Write-Host "Szczegóły: $($_.Exception.Message)"
    }
}

# endregion

# Menu wyboru funkcji
Write-Host "==== Główne Menu ====" -ForegroundColor Cyan
Write-Host ""
Write-Host "1. Zarządzaj programami (instalacja/deinstalacja)"
Write-Host "2. Zarządzaj funkcjami Windows (włączanie/wyłączanie)"
Write-Host "q. Zakończ"
Write-Host ""
Write-Host "Wybierz opcję: " -NoNewline

$menuChoice = Read-Host

switch ($menuChoice) {
    "1" {
        Check-Admin
        Check-Chocolatey
        
        $appsData = Get-JsonData "apps.json"
        if (-not $appsData) {
            Write-Host "Nie można kontynuować z powodu błędów pobierania danych konfiguracyjnych." -ForegroundColor $colors.Error
            Read-Host "Naciśnij Enter, aby zakończyć..."
            exit
        }
        
        $allApps = [System.Collections.Generic.List[object]]::new()
        foreach ($category in $appsData) {
            if ($null -ne $category.Apps) {
                $allApps.AddRange($category.Apps)
            }
        }

        do {
            Clear-Host
            $appChoiceString = Show-AppsMenu -appsData $appsData
            if ($appChoiceString -eq "q") { break }

            if ($appChoiceString -eq "s") {
                $searchResult = Search-Apps-Interactive -allApps $allApps
                if ($null -ne $searchResult) {
                    $appChoiceString = $searchResult
                }
                else {
                    continue
                }
            }

            $appChoices = $appChoiceString.Split(',')

            if ($appChoices.Count -gt 0 -and $appChoiceString) {
                Write-Host "`nWybrano numery: $($appChoiceString)" -ForegroundColor $colors.Highlight
                Write-Host "1. Zainstaluj"
                Write-Host "2. Odinstaluj"
                $actionChoice = Read-Host "Wybierz akcję dla wszystkich wybranych programów"

                $customPath = ""
                if ($actionChoice -eq "1") {
                    $pathChoice = Read-Host "Czy chcesz podać niestandardową ścieżkę instalacji dla wszystkich programów? (y/n)"
                    if ($pathChoice -eq 'y') {
                        $customPath = Read-Host "Podaj pełną ścieżkę instalacji (np. D:\Programy)"
                    }
                }

                foreach ($choice in $appChoices) {
                    $trimmedChoice = $choice.Trim()
                    if ($trimmedChoice -match "^\d+$" -and [int]$trimmedChoice -gt 0 -and [int]$trimmedChoice -le $allApps.Count) {
                        $selectedIndex = [int]$trimmedChoice - 1
                        $selectedApp = $allApps[$selectedIndex]
                        
                        Write-Host "`n--- Przetwarzanie: $($selectedApp.Name) ---" -ForegroundColor $colors.Highlight

                        if ($actionChoice -eq "1") {
                            Invoke-ChocoCommand -Command "install" -PackageId $selectedApp.ChocoId -InstallPath $customPath
                        }
                        elseif ($actionChoice -eq "2") {
                            Invoke-ChocoCommand -Command "uninstall" -PackageId $selectedApp.ChocoId
                        }
                        else {
                            Write-Host "Pominięto z powodu nieprawidłowego wyboru akcji (1 lub 2)." -ForegroundColor $colors.Error
                            break
                        }
                    }
                    else {
                        Write-Host "`n--- Pominięto nieprawidłowy numer: '$($choice.Trim())' ---" -ForegroundColor $colors.Error
                    }
                }
            }
            else {
                Write-Host "Nie wprowadzono żadnego numeru." -ForegroundColor $colors.Error
            }
            Read-Host "Wszystkie operacje zakończone. Naciśnij Enter, aby kontynuować..."
        } while ($true)
    }
    "2" {
        Check-Admin
        
        $featuresData = Get-JsonData "features.json"
        if (-not $featuresData) {
            Write-Host "Nie można kontynuować z powodu błędów pobierania danych konfiguracyjnych." -ForegroundColor $colors.Error
            Read-Host "Naciśnij Enter, aby zakończyć..."
            exit
        }

        do {
            Clear-Host
            $featureChoice = Show-FeaturesMenu($featuresData)
            if ($featureChoice -eq "q") { break }

            if ($featureChoice -match "^\d+$" -and $featureChoice -gt 0 -and $featureChoice -le $featuresData.Count) {
                $selectedIndex = [int]$featureChoice - 1
                $selectedFeature = $featuresData[$selectedIndex]
                
                Write-Host "`nWybrano: $($selectedFeature.Name)" -ForegroundColor $colors.Highlight
                Write-Host "1. Włącz"
                Write-Host "2. Wyłącz"
                $actionChoice = Read-Host "Wybierz akcję"
                
                try {
                    if ($selectedFeature.Type -eq "WindowsFeature") {
                        switch ($actionChoice) {
                            "1" {
                                Write-Host "`nWłączam funkcję $($selectedFeature.Name)..." -ForegroundColor $colors.Info
                                Enable-WindowsOptionalFeature -Online -FeatureName $selectedFeature.FeatureName -All -NoRestart
                                Write-Host "Funkcja włączona. Może być wymagane ponowne uruchomienie komputera." -ForegroundColor $colors.Success
                            }
                            "2" {
                                Write-Host "`nWyłączam funkcję $($selectedFeature.Name)..." -ForegroundColor $colors.Info
                                Disable-WindowsOptionalFeature -Online -FeatureName $selectedFeature.FeatureName -NoRestart
                                Write-Host "Funkcja wyłączona. Może być wymagane ponowne uruchomienie komputera." -ForegroundColor $colors.Success
                            }
                            default {
                                Write-Host "Nieprawidłowy wybór." -ForegroundColor $colors.Error
                            }
                        }
                    }
                    elseif ($selectedFeature.Type -eq "Registry") {
                        switch ($actionChoice) {
                            "1" {
                                Write-Host "`nWłączam tweak: $($selectedFeature.Name)..." -ForegroundColor $colors.Info
                                $success = Set-RegistryTweak -Path $selectedFeature.FeatureName -ValueName $selectedFeature.ValueName -Value $selectedFeature.EnableValue
                                if ($success) {
                                    Write-Host "Tweak włączony pomyślnie." -ForegroundColor $colors.Success
                                }
                            }
                            "2" {
                                Write-Host "`nWyłączam tweak: $($selectedFeature.Name)..." -ForegroundColor $colors.Info
                                $success = Set-RegistryTweak -Path $selectedFeature.FeatureName -ValueName $selectedFeature.ValueName -Value $selectedFeature.DisableValue
                                if ($success) {
                                    Write-Host "Tweak wyłączony pomyślnie." -ForegroundColor $colors.Success
                                }
                            }
                            default {
                                Write-Host "Nieprawidłowy wybór." -ForegroundColor $colors.Error
                            }
                        }
                    }
                    else {
                        Write-Host "Nieznany typ funkcji: $($selectedFeature.Type)" -ForegroundColor $colors.Error
                    }
                }
                catch {
                     Write-Host "Wystąpił błąd podczas zmiany statusu funkcji." -ForegroundColor $colors.Error
                     Write-Host "Szczegóły: $($_.Exception.Message)"
                }
            }
            else {
                Write-Host "Nieprawidłowy numer. Spróbuj ponownie." -ForegroundColor $colors.Error
            }
            Read-Host "Naciśnij Enter, aby kontynuować..."
        } while ($true)
    }
    "q" {
        Write-Host "Zamykanie MyTool. Do widzenia!" -ForegroundColor Green
    }
    default {
        Write-Host "Nieprawidłowy wybór. Zamykanie..." -ForegroundColor Red
    }
}
