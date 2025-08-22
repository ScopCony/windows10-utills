# MyTool.ps1
#
# To jest narzędzie PowerShell do instalacji/deinstalacji programów
# i zarządzania funkcjami Windows, bazujące na zewnętrznym repozytorium GitHub.
#
# Działanie:
# 1. Sprawdza uprawnienia administratora.
# 2. Pobiera pliki konfiguracyjne JSON z repozytorium GitHub.
# 3. Wyświetla menu tekstowe z opcjami.
# 4. Wykonuje odpowiednie polecenia (choco, dism) na podstawie danych z plików JSON.
#
# Autor: Sebastian Brański
# Wersja: 1.9 - Pogrubiono nazwy aplikacji w menu.

# region Wymuszenie kodowania
# Ta linia zapewnia poprawne wyświetlanie polskich znaków
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::InputEncoding = [System.Text.Encoding]::UTF8
# endregion

# region Konfiguracja
# Zmień ten URL na link do Twojego repozytorium na GitHub!
# Pamiętaj, aby wskazywał na główną gałąź i surowy plik JSON.
# UWAGA: Ten URL jest poprawiony na podstawie Twojego zrzutu ekranu.
$githubRepoUrl = "https://raw.githubusercontent.com/ScopCony/windows10-utills/main"
# endregion

# region Funkcje pomocnicze

function Check-Admin {
    # Sprawdza, czy skrypt jest uruchomiony z uprawnieniami administratora.
    $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    if (-not $isAdmin) {
        Write-Host "Ten skrypt musi być uruchomiony z uprawnieniami administratora." -ForegroundColor Red
        Write-Host "Kliknij prawym przyciskiem myszy na PowerShell i wybierz 'Uruchom jako administrator'."
        Read-Host "Naciśnij Enter, aby zakończyć..."
        exit
    }
}

function Get-JsonData($fileName) {
    # Pobiera plik JSON z GitHub.
    $url = "$($githubRepoUrl)/config/$($fileName)"
    try {
        Write-Host "Pobieram dane z $url..." -ForegroundColor Green
        # Użycie WebClient i kodowania UTF-8 do poprawnego wyświetlania polskich znaków
        $webClient = New-Object System.Net.WebClient
        $webClient.Encoding = [System.Text.Encoding]::UTF8
        $json = $webClient.DownloadString($url)
        return $json | ConvertFrom-Json
    }
    catch {
        Write-Host "Błąd podczas pobierania pliku $fileName." -ForegroundColor Red
        Write-Host "Szczegóły błędu: $($_.Exception.Message)"
        return $null
    }
}

function Show-AppsMenu($appsData) {
    # Wyświetla menu programów z pogrubionymi nazwami.
    Write-Host "`n==== Zarządzanie programami ====`n"
    
    $global:allApps = @()
    $count = 1

    foreach ($category in $appsData) {
        Write-Host "`n---- $($category.Category) ----" -ForegroundColor Yellow
        foreach ($app in $category.Apps) {
            # Pogrubienie nazwy aplikacji
            Write-Host "$count. `e[1m$($app.Name)`e[0m - $($app.Description)"
            $global:allApps += $app
            $count++
        }
    }

    Write-Host "`nq. Powrót do głównego menu`n"
    $choice = Read-Host "Wybierz numer, aby zainstalować lub odinstalować program"
    return $choice
}

function Show-FeaturesMenu($features) {
    # Wyświetla menu funkcji Windows.
    Write-Host "`n==== Zarządzanie funkcjami Windows ====`n"
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
        Write-Host "`n==== Główne Menu ====`n"
        Write-Host "1. Zarządzaj programami (instalacja/deinstalacja)"
        Write-Host "2. Zarządzaj funkcjami Windows (włączanie/wyłączanie)"
        Write-Host "q. Zakończ"

        $mainChoice = Read-Host "Wybierz opcję"

        switch ($mainChoice) {
            "1" {
                do {
                    $appChoice = Show-AppsMenu($appsData)
                    if ($appChoice -eq "q") { break }

                    if ($appChoice -match "^\d+$" -and [int]$appChoice -le $global:allApps.Count) {
                        $selectedIndex = [int]$appChoice - 1
                        $selectedApp = $global:allApps[$selectedIndex]
                        
                        Write-Host "`nWybrano: $($selectedApp.Name)" -ForegroundColor Yellow
                        Write-Host "1. Zainstaluj"
                        Write-Host "2. Odinstaluj"
                        $actionChoice = Read-Host "Wybierz akcję"

                        if ($actionChoice -eq "1") {
                            $installPath = Read-Host "Czy chcesz zainstalować domyślnie na C:\Program Files? (y/n)"
                            if ($installPath -eq "y") {
                                Write-Host "`nRozpoczynam instalację $($selectedApp.Name) przez Chocolatey..."
                                choco install "$($selectedApp.ChocoId)"
                            } else {
                                $customPath = Read-Host "Podaj ścieżkę instalacji (np. D:\Programy)"
                                Write-Host "`nRozpoczynam instalację $($selectedApp.Name) do $customPath przez Chocolatey..."
                                choco install "$($selectedApp.ChocoId)" --install-location "'$customPath'"
                            }
                        } elseif ($actionChoice -eq "2") {
                            Write-Host "`nRozpoczynam deinstalację $($selectedApp.Name) przez Chocolatey..."
                            choco uninstall "$($selectedApp.ChocoId)"
                        } else {
                            Write-Host "Nieprawidłowy wybór. Spróbuj ponownie." -ForegroundColor Red
                        }
                    } else {
                        Write-Host "Nieprawidłowy wybór. Spróbuj ponownie." -ForegroundColor Red
                    }
                } while ($true)
            }
            "2" {
                do {
                    $featureChoice = Show-FeaturesMenu($featuresData)
                    if ($featureChoice -eq "q") { break }

                    if ($featureChoice -match "^\d+$" -and $featureChoice -le $featuresData.Count) {
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
                    } else {
                        Write-Host "Nieprawidłowy wybór. Spróbuj ponownie." -ForegroundColor Red
                    }
                } while ($true)
            }
            "q" {
                Write-Host "Zamykanie narzędzia. Do widzenia!"
                exit
            }
            default {
                Write-Host "Nieprawidłowy wybór. Spróbuj ponownie." -ForegroundColor Red
            }
        }
    } while ($true)
}

# endregion

# Uruchomienie skryptu
Check-Admin
Main-Menu
