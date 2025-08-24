# Sprawdzanie wersji systemu
$os = Get-CimInstance -ClassName Win32_OperatingSystem
if ($os.Caption -notlike "*Windows 10*") {
    Write-Host "This script is designed for Windows 10 only." -ForegroundColor Red
    exit
}

# Funkcja do odinstalowywania aplikacji
function Uninstall-App {
    param (
        [string]$AppName
    )
    $app = Get-AppxPackage -Name $AppName -ErrorAction SilentlyContinue
    if ($app) {
        Write-Host "Uninstalling $AppName..." -ForegroundColor Yellow
        Remove-AppxPackage -Package $app.PackageFullName -ErrorAction Stop
        Write-Host "$AppName uninstalled successfully." -ForegroundColor Green
    } else {
        Write-Host "$AppName is not installed." -ForegroundColor Gray
    }
}

# Funkcja do instalacji pakietów Chocolatey
function Install-ChocolateyPackage {
    param (
        [string]$PackageName
    )
    if (Get-Command choco -ErrorAction SilentlyContinue) {
        Write-Host "Installing $PackageName via Chocolatey..." -ForegroundColor Yellow
        choco install $PackageName -y
    } else {
        Write-Host "Chocolatey not found. Installing Chocolatey first..." -ForegroundColor Yellow
        Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
        Write-Host "Installing $PackageName via Chocolatey..." -ForegroundColor Yellow
        choco install $PackageName -y
    }
}

# Funkcja do konfiguracji ustawień prywatności
function Configure-PrivacySettings {
    Write-Host "Configuring privacy settings..." -ForegroundColor Yellow

    # Wyłącz telemetrię
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection" -Name "AllowTelemetry" -Value 0 -Type DWord -ErrorAction SilentlyContinue
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\DataCollection" -Name "AllowTelemetry" -Value 0 -Type DWord -ErrorAction SilentlyContinue

    # Wyłącz Cortanę
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search" -Name "AllowCortana" -Value 0 -Type DWord -ErrorAction SilentlyContinue

    # Wyłącz lokalizację
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\LocationAndSensors" -Name "DisableLocation" -Value 1 -Type DWord -ErrorAction SilentlyContinue

    # Wyłącz synchronizację ustawień
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\SettingSync" -Name "DisableSettingSync" -Value 2 -Type DWord -ErrorAction SilentlyContinue

    Write-Host "Privacy settings configured." -ForegroundColor Green
}

# Funkcja do optymalizacji systemu
function Optimize-System {
    Write-Host "Optimizing system..." -ForegroundColor Yellow

    # Wyłącz animacje
    Set-ItemProperty -Path "HKCU:\Control Panel\Desktop\WindowMetrics" -Name "MinAnimate" -Value 0 -Type String -ErrorAction SilentlyContinue

    # Wyłącz efekty wizualne
    Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects" -Name "VisualFXSetting" -Value 2 -Type DWord -ErrorAction SilentlyContinue

    # Optymalizacja usług
    $services = @(
        "DiagTrack",
        "dmwappushservice",
        "WSearch"
    )
    foreach ($service in $services) {
        if (Get-Service -Name $service -ErrorAction SilentlyContinue) {
            Stop-Service -Name $service -Force -ErrorAction SilentlyContinue
            Set-Service -Name $service -StartupType Disabled -ErrorAction SilentlyContinue
            Write-Host "$service disabled." -ForegroundColor Green
        }
    }

    Write-Host "System optimization completed." -ForegroundColor Green
}

# Funkcja do usuwania OneDrive
function Remove-OneDrive {
    Write-Host "Removing OneDrive..." -ForegroundColor Yellow

    # Zatrzymaj procesy OneDrive
    taskkill /f /im OneDrive.exe 2>nul

    # Odinstaluj OneDrive
    $oneDriveSetup = "$env:SystemRoot\System32\OneDriveSetup.exe"
    if (Test-Path $oneDriveSetup) {
        Start-Process -FilePath $oneDriveSetup -ArgumentList "/uninstall" -Wait -NoNewWindow
    }

    # Usuń folder OneDrive
    $oneDriveFolder = "$env:USERPROFILE\OneDrive"
    if (Test-Path $oneDriveFolder) {
        Remove-Item -Path $oneDriveFolder -Recurse -Force -ErrorAction SilentlyContinue
    }

    Write-Host "OneDrive removed." -ForegroundColor Green
}

# Menu główne
function Show-Menu {
    Clear-Host
    Write-Host "================ MyTool ================" -ForegroundColor Cyan
    Write-Host "1: Uninstall bloatware" -ForegroundColor White
    Write-Host "2: Install useful software" -ForegroundColor White
    Write-Host "3: Configure privacy settings" -ForegroundColor White
    Write-Host "4: Optimize system" -ForegroundColor White
    Write-Host "5: Remove OneDrive" -ForegroundColor White
    Write-Host "6: Exit" -ForegroundColor White
    Write-Host "========================================" -ForegroundColor Cyan
}

# Funkcja do odinstalowywania zbędnych aplikacji
function Uninstall-Bloatware {
    Write-Host "Uninstalling bloatware..." -ForegroundColor Yellow
    $bloatware = @(
        "Microsoft.3DBuilder",
        "Microsoft.BingFinance",
        "Microsoft.BingNews",
        "Microsoft.BingSports",
        "Microsoft.BingWeather",
        "Microsoft.GetHelp",
        "Microsoft.Getstarted",
        "Microsoft.Messaging",
        "Microsoft.Microsoft3DViewer",
        "Microsoft.MicrosoftOfficeHub",
        "Microsoft.MicrosoftSolitaireCollection",
        "Microsoft.MixedReality.Portal",
        "Microsoft.Office.Lens",
        "Microsoft.Office.Sway",
        "Microsoft.OneConnect",
        "Microsoft.People",
        "Microsoft.Print3D",
        "Microsoft.SkypeApp",
        "Microsoft.StorePurchaseApp",
        "Microsoft.Whiteboard",
        "Microsoft.WindowsAlarms",
        "Microsoft.WindowsCamera",
        "microsoft.windowscommunicationsapps",
        "Microsoft.WindowsFeedbackHub",
        "Microsoft.WindowsMaps",
        "Microsoft.WindowsSoundRecorder",
        "Microsoft.Xbox.TCUI",
        "Microsoft.XboxApp",
        "Microsoft.XboxGameOverlay",
        "Microsoft.XboxGamingOverlay",
        "Microsoft.XboxIdentityProvider",
        "Microsoft.XboxSpeechToTextOverlay",
        "Microsoft.ZuneMusic",
        "Microsoft.ZuneVideo"
    )

    foreach ($app in $bloatware) {
        Uninstall-App -AppName $app
    }
}

# Funkcja do instalacji przydatnego oprogramowania
function Install-UsefulSoftware {
    Write-Host "Installing useful software..." -ForegroundColor Yellow
    $packages = @(
        "googlechrome",
        "7zip",
        "notepadplusplus",
        "vlc"
    )

    foreach ($package in $packages) {
        Install-ChocolateyPackage -PackageName $package
    }
}

# Nowa funkcja interaktywnego wyszukiwania
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
            
            # Pokazuj propozycje automatycznie jeśli jest wyszukiwanie
            Show-AutocompleteHints -allApps $allApps -searchTerm $searchTerm
        }
        
        if (-not [string]::IsNullOrEmpty($numberInput)) {
            Write-Host "`nWpisywany numer: $numberInput" -ForegroundColor $colors.Highlight
        }
        
        Write-Host "`nWpisz znak (TAB=uzupełnij, ENTER=wybierz więcej, ESC=wyczyść, Q=wyjście):" -ForegroundColor $colors.Info
        
        # Czytaj pojedyncze naciśnięcie klawisza
        $key = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        
        switch ($key.VirtualKeyCode) {
            9 { # TAB
                # Wyczyść wprowadzany numer przy TAB
                $numberInput = ""
                
                # Znajdź wszystkie programy pasujące do aktualnego wyszukiwania
                $matchingApps = [System.Collections.Generic.List[string]]::new()
                foreach ($app in $allApps) {
                    if ($app.Name -like "$searchTerm*") {
                        $matchingApps.Add($app.Name)
                    }
                }
                
                if ($matchingApps.Count -eq 0) {
                    # Brak dopasowań - nic nie rób
                    continue
                }
                elseif ($matchingApps.Count -eq 1) {
                    # Jedna opcja - uzupełnij całą nazwę
                    $searchTerm = $matchingApps[0]
                }
                else {
                    # Wiele opcji - znajdź wspólny prefiks
                    $commonPrefix = Find-CommonPrefix -suggestions $matchingApps -currentTerm $searchTerm
                    
                    if ($commonPrefix.Length -gt $searchTerm.Length) {
                        # Jest dłuższy wspólny prefiks - uzupełnij do niego
                        $searchTerm = $commonPrefix
                    }
                    # Jeśli nie ma dłuższego wspólnego prefiksu - nic nie rób (jak w Linux)
                }
                
                # Aktualizacja wyników po każdej zmianie
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
                    # Usuń ostatnią cyfrę z wprowadzanego numeru
                    if ($numberInput.Length -gt 1) {
                        $numberInput = $numberInput.Substring(0, $numberInput.Length - 1)
                    } else {
                        $numberInput = ""
                    }
                }
                elseif ($searchTerm.Length -gt 0) {
                    $searchTerm = $searchTerm.Substring(0, $searchTerm.Length - 1)
                    # Aktualizacja wyników
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
                # Sprawdź czy użytkownik wpisał numer
                if (-not [string]::IsNullOrEmpty($numberInput)) {
                    $inputNumber = [int]$numberInput
                    # Sprawdź czy ten numer jest w wynikach wyszukiwania
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

                # Konwersja wyborów - sprawdź czy wpisane numery to oryginalne numery z wyników
                $searchChoices = $choice.Split(',')
                $originalNumbers = [System.Collections.Generic.List[string]]::new()
                
                foreach ($searchChoice in $searchChoices) {
                    $trimmedChoice = $searchChoice.Trim()
                    if ($trimmedChoice -match "^\d+$") {
                        $inputNumber = [int]$trimmedChoice
                        # Sprawdź czy ten numer jest w wynikach wyszukiwania
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
                # Sprawdź czy to cyfra
                $char = $key.Character
                if ($char -match '[0-9]') {
                    # Sprawdź czy mamy wyniki wyszukiwania
                    if ($foundApps.Count -gt 0) {
                        $numberInput += $char
                        
                        # Sprawdź czy wprowadzany numer już pasuje do któregoś wyniku
                        if ($numberInput -match "^\d+$") {
                            $potentialNumber = [int]$numberInput
                            foreach ($foundApp in $foundApps) {
                                if ($foundApp.OriginalIndex -eq $potentialNumber) {
                                    # Znaleziono pasujący numer - od razu zwróć
                                    return $potentialNumber.ToString()
                                }
                            }
                        }
                    } else {
                        # Jeśli nie ma wyników, cyfra jest częścią wyszukiwania
                        $searchTerm += $char
                        $numberInput = ""
                        
                        # Aktualizacja wyników wyszukiwania
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
                    # Litera - czyści wprowadzany numer i dodaje do wyszukiwania
                    $numberInput = ""
                    $searchTerm += $char
                    
                    # Aktualizacja wyników wyszukiwania
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

# Główna pętla skryptu
do {
    Show-Menu
    $input = Read-Host "Please select an option"
    switch ($input) {
        '1' {
            Uninstall-Bloatware
        }
        '2' {
            Install-UsefulSoftware
        }
        '3' {
            Configure-PrivacySettings
        }
        '4' {
            Optimize-System
        }
        '5' {
            Remove-OneDrive
        }
        '6' {
            Write-Host "Exiting..." -ForegroundColor Cyan
            exit
        }
        default {
            Write-Host "Invalid option. Please select again." -ForegroundColor Red
        }
    }
    Write-Host "Press any key to continue..."
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
} while ($true)
