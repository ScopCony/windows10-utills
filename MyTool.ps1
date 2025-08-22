# MyTool.ps1
#
# To jest narzędzie PowerShell do instalacji/deinstalacji programów
# i zarządzania funkcjami Windows, bazujące na zewnętrznym repozytorium GitHub.
#
# Działanie:
# 1. Sprawdza uprawnienia administratora i w razie potrzeby prosi o ich nadanie.
# 2. Sprawdza, czy Chocolatey jest zainstalowany, i w razie potrzeby instaluje go.
# 3. Pobiera pliki konfiguracyjne JSON z repozytorium GitHub.
# 4. Wyświetla menu tekstowe z opcjami.
# 5. Wykonuje odpowiednie polecenia (choco, DISM) na podstawie danych z plików JSON.
#
# Autor: asystent Gemini
# Wersja: 1.2 - Poprawki błędów, dodano sprawdzanie Chocolatey

# region Konfiguracja
# Zmień ten URL na link do Twojego repozytorium na GitHub!
# Pamiętaj, aby wskazywał na surowy plik (raw).
# Przykład: https://raw.githubusercontent.com/TWOJA_NAZWA_UZYTKOWNIKA/TWOJE_REPOZYTORIUM/main
$githubRepoUrl = "https://raw.githubusercontent.com/TWOJA_NAZWA_UZYTKOWNIKA/TWOJE_REPOZYTORIUM/main"
# endregion

# region Funkcje pomocnicze

function Check-Admin {
    # Sprawdza, czy skrypt jest uruchomiony z uprawnieniami administratora.
    $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    if (-not $isAdmin) {
        Write-Warning "Skrypt wymaga uprawnień administratora. Próba ponownego uruchomienia..."
        # Próba ponownego uruchomienia skryptu z uprawnieniami administratora
        Start-Process powershell -Verb RunAs -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
        exit
    }
}

function Check-Chocolatey {
    # Sprawdza, czy Chocolatey jest zainstalowany.
    $chocoPath = Get-Command choco -ErrorAction SilentlyContinue
    if (-not $chocoPath) {
        Write-Host "Chocolatey nie jest zainstalowany." -ForegroundColor Yellow
        $installChoice = Read-Host "Czy chcesz zainstalować Chocolatey teraz? (t/n)"
        if ($installChoice -eq 't') {
            Write-Host "Instalowanie Chocolatey..." -ForegroundColor Green
            Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
            Write-Host "Instalacja Chocolatey zakończona. Uruchom skrypt ponownie." -ForegroundColor Green
            Read-Host "Naciśnij Enter, aby zakończyć..."
            exit
        }
        else {
            Write-Host "Instalacja Chocolatey jest wymagana do zarządzania programami." -ForegroundColor Red
            Read-Host "Naciśnij Enter, aby zakończyć..."
            exit
        }
    }
}


function Get-JsonData($fileName) {
    # Pobiera i konwertuje plik JSON z GitHub.
    # POPRAWKA: Usunięto niepoprawny format linku Markdown.
    $url = "$($githubRepoUrl)/config/$($fileName)"
    try {
        Write-Host "Pobieram dane z $url..." -ForegroundColor Cyan
        # POPRAWKA: Invoke-RestMethod automatycznie konwertuje JSON na obiekt,
        # więc dodatkowe `ConvertFrom-Json` powodowało błąd i zostało usunięte.
        $jsonData = Invoke-RestMethod -Uri $url -Method Get
        return $jsonData
    }
    catch {
        Write-Host "Błąd podczas pobierania pliku $fileName." -ForegroundColor Red
        Write-Host "Sprawdź, czy URL w zmiennej `$githubRepoUrl` jest poprawny i czy plik istnieje."
        Write-Host "Szczegóły błędu: $($_.Exception.Message)"
        return $null
    }
}

function Show-AppsMenu($apps) {
    # Wyświetla menu programów.
    Write-Host "`n==== Zarządzanie programami ====`n" -ForegroundColor White
    for ($i = 0; $i -lt $apps.Count; $i++) {
        Write-Host "$($i + 1). $($apps[$i].Name) - $($apps[$i].Description)"
    }
    Write-Host "`nq. Powrót do głównego menu`n"
    $choice = Read-Host "Wybierz numer, aby zainstalować lub odinstalować program"
    return $choice
}

function Show-FeaturesMenu($features) {
    # Wyświetla menu funkcji Windows.
    Write-Host "`n==== Zarządzanie funkcjami Windows ====`n" -ForegroundColor White
    for ($i = 0; $i -lt $features.Count; $i++) {
        Write-Host "$($i + 1). $($features[$i].Name) - $($features[$i].Description)"
    }
    Write-Host "`nq. Powrót do głównego menu`n"
    $choice = Read-Host "Wybierz numer, aby włączyć/wyłączyć funkcję"
    return $choice
}

function Main-Menu {
    # Główna pętla menu.
    $appsData = Get-JsonData "apps.json"
    $featuresData = Get-JsonData "features.json"

    if (-not $appsData -or -not $featuresData) {
        Write-Host "Nie można kontynuować z powodu błędów pobierania danych konfiguracyjnych." -ForegroundColor Red
        Read-Host "Naciśnij Enter, aby zakończyć..."
        exit
    }
    
    do {
        Clear-Host
        Write-Host "`n==== Główne Menu ====`n" -ForegroundColor Green
        Write-Host "1. Zarządzaj programami (instalacja/deinstalacja)"
        Write-Host "2. Zarządzaj funkcjami Windows (włączanie/wyłączanie)"
        Write-Host "q. Zakończ"

        $mainChoice = Read-Host "Wybierz opcję"

        switch ($mainChoice) {
            "1" {
                do {
                    Clear-Host
                    $appChoice = Show-AppsMenu($appsData)
                    if ($appChoice -eq "q") { break }

                    if ($appChoice -match "^\d+$" -and $appChoice -gt 0 -and $appChoice -le $appsData.Count) {
                        $selectedIndex = [int]$appChoice - 1
                        $selectedApp = $appsData[$selectedIndex]
                        
                        Write-Host "`nWybrano: $($selectedApp.Name)" -ForegroundColor Yellow
                        Write-Host "1. Zainstaluj"
                        Write-Host "2. Odinstaluj"
                        $actionChoice = Read-Host "Wybierz akcję"

                        switch ($actionChoice) {
                            "1" {
                                Write-Host "`nRozpoczynam instalację $($selectedApp.Name) przez Chocolatey..."
                                # POPRAWKA: Dodano przełącznik -y, aby automatycznie potwierdzić instalację.
                                choco install "$($selectedApp.ChocoId)" -y
                            }
                            "2" {
                                Write-Host "`nRozpoczynam deinstalację $($selectedApp.Name) przez Chocolatey..."
                                # POPRAWKA: Dodano przełącznik -y, aby automatycznie potwierdzić deinstalację.
                                choco uninstall "$($selectedApp.ChocoId)" -y
                            }
                            default {
                                Write-Host "Nieprawidłowy wybór. Spróbuj ponownie." -ForegroundColor Red
                            }
                        }
                        Read-Host "`nNaciśnij Enter, aby kontynuować..."
                    } else {
                        Write-Host "Nieprawidłowy wybór. Spróbuj ponownie." -ForegroundColor Red
                        Start-Sleep -Seconds 2
                    }
                } while ($true)
            }
            "2" {
                do {
                    Clear-Host
                    $featureChoice = Show-FeaturesMenu($featuresData)
                    if ($featureChoice -eq "q") { break }

                    if ($featureChoice -match "^\d+$" -and $featureChoice -gt 0 -and $featureChoice -le $featuresData.Count) {
                        $selectedIndex = [int]$featureChoice - 1
                        $selectedFeature = $featuresData[$selectedIndex]
                        
                        Write-Host "`nWybrano: $($selectedFeature.Name)" -ForegroundColor Yellow
                        Write-Host "1. Włącz"
                        Write-Host "2. Wyłącz"
                        $actionChoice = Read-Host "Wybierz akcję"
                        
                        switch ($actionChoice) {
                            "1" {
                                Write-Host "`nWłączam funkcję $($selectedFeature.Name)..."
                                Enable-WindowsOptionalFeature -Online -FeatureName $selectedFeature.FeatureName -All
                            }
                            "2" {
                                Write-Host "`nWyłączam funkcję $($selectedFeature.Name)..."
                                Disable-WindowsOptionalFeature -Online -FeatureName $selectedFeature.FeatureName
                            }
                            default {
                                Write-Host "Nieprawidłowy wybór. Spróbuj ponownie." -ForegroundColor Red
                            }
                        }
                        Write-Host "Operacja może wymagać ponownego uruchomienia komputera." -ForegroundColor Yellow
                        Read-Host "`nNaciśnij Enter, aby kontynuować..."
                    } else {
                        Write-Host "Nieprawidłowy wybór. Spróbuj ponownie." -ForegroundColor Red
                        Start-Sleep -Seconds 2
                    }
                } while ($true)
            }
            "q" {
                Write-Host "Zamykanie narzędzia. Do widzenia!"
                exit
            }
            default {
                Write-Host "Nieprawidłowy wybór. Spróbuj ponownie." -ForegroundColor Red
                Start-Sleep -Seconds 2
            }
        }
    } while ($true)
}

# endregion

# Uruchomienie skryptu
Check-Admin
Check-Chocolatey
Main-Menu
