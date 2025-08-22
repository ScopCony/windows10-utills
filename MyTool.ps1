# MyTool.ps1
#
# To jest narzędzie PowerShell do instalacji/deinstalacji programów
# i zarządzania funkcjami Windows, bazujące na zewnętrznym repozytorium GitHub.
#
# Działanie:
# 1. Sprawdza uprawnienia administratora.
# 2. Sprawdza, czy Chocolatey jest zainstalowany i proponuje instalację.
# 3. Pobiera pliki konfiguracyjne JSON z repozytorium GitHub.
# 4. Wyświetla menu tekstowe z opcjami.
# 5. Wykonuje odpowiednie polecenia (choco, dism) z ulepszoną obsługą błędów.
#
# Autor: Sebastian Brański
# Wersja: 4.5 - Przywrócono opisy programów w widoku jednokolumnowym.

# region Zmiana kolorów konsoli
# Ustawia tło na czarne i tekst na biały, aby zapewnić spójny wygląd.
$Host.UI.RawUI.BackgroundColor = "Black"
$Host.UI.RawUI.ForegroundColor = "White"
Clear-Host
# endregion

# region Wymuszenie kodowania
# Ta linia zapewnia poprawne wyświetlanie polskich znaków
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::InputEncoding = [System.Text.Encoding]::UTF8
# endregion

# region Konfiguracja
# URL do repozytorium GitHub z plikami konfiguracyjnymi.
$githubRepoUrl = "https://raw.githubusercontent.com/ScopCony/windows10-utills/main"
# endregion

# region Funkcje pomocnicze

function Check-Admin {
    # Sprawdza, czy skrypt jest uruchomiony z uprawnieniami administratora.
    $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    if (-not $isAdmin) {
        Write-Host "Ten skrypt musi być uruchomiony z uprawnieniami administratora." -ForegroundColor Red
        Write-Host "Proszę zamknij to okno i uruchom ponownie PowerShell jako administrator."
        Write-Host "Następnie użyj komendy:"
        Write-Host "irm https://raw.githubusercontent.com/ScopCony/windows10-utills/main/MyTool.ps1 | iex"
        Read-Host "Naciśnij Enter, aby zamknąć..."
        exit
    }
}

function Check-Chocolatey {
    # Sprawdza, czy polecenie 'choco' jest dostępne.
    $chocoExists = Get-Command choco -ErrorAction SilentlyContinue
    if (-not $chocoExists) {
        Write-Host "Narzędzie Chocolatey nie zostało znalezione." -ForegroundColor Yellow
        $installChoice = Read-Host "Czy chcesz je teraz zainstalować? (y/n)"
        if ($installChoice -eq 'y') {
            Write-Host "Instalowanie Chocolatey..." -ForegroundColor Green
            try {
                Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
                Write-Host "Chocolatey został pomyślnie zainstalowany. Uruchom skrypt ponownie." -ForegroundColor Green
            }
            catch {
                Write-Host "Wystąpił błąd podczas instalacji Chocolatey." -ForegroundColor Red
                Write-Host "Szczegóły błędu: $($_.Exception.Message)"
            }
            Read-Host "Naciśnij Enter, aby zamknąć..."
            exit
        }
        else {
            Write-Host "Instalacja programów nie będzie możliwa bez Chocolatey. Zamykanie skryptu." -ForegroundColor Red
            Read-Host "Naciśnij Enter, aby zamknąć..."
            exit
        }
    }
    else {
        Write-Host "Znaleziono zainstalowane narzędzie Chocolatey." -ForegroundColor Green
    }
}


function Get-JsonData($fileName) {
    # Pobiera i parsuje plik JSON z GitHub.
    $url = "$($githubRepoUrl)/config/$($fileName)"
    try {
        Write-Host "Pobieram dane z $url..." -ForegroundColor Cyan
        $data = Invoke-RestMethod -Uri $url
        return $data
    }
    catch {
        Write-Host "Błąd podczas pobierania pliku $fileName." -ForegroundColor Red
        Write-Host "Szczegóły błędu: $($_.Exception.Message)"
        return $null
    }
}

# ZMIANA: Powrót do widoku jednokolumnowego, aby wyświetlić opisy programów.
function Show-AppsMenu($appsData) {
    Write-Host "`n==== Zarządzanie programami ====`n" -ForegroundColor Magenta
    
    $count = 1 # Ogólny licznik dla numeracji programów

    foreach ($category in $appsData) {
        Write-Host "`n---- $($category.Category) ----" -ForegroundColor Magenta
        
        foreach ($app in $category.Apps) {
            # Formatowanie: Numer. Nazwa - Opis
            Write-Host ("{0,3}. " -f $count) -ForegroundColor Green -NoNewline
            Write-Host $app.Name -ForegroundColor Yellow -NoNewline
            Write-Host " - $($app.Description)" -ForegroundColor White
            $count++
        }
    }

    Write-Host "`nq. Powrót do głównego menu`n"
    $choice = Read-Host "Wybierz numer, aby zainstalować lub odinstalować program"
    return $choice
}

function Show-FeaturesMenu($features) {
    # Wyświetla menu funkcji Windows.
    Write-Host "`n==== Zarządzanie funkcjami Windows ====`n" -ForegroundColor Magenta
    for ($i = 0; $i -lt $features.Count; $i++) {
        $feature = $features[$i]
        $status = (Get-WindowsOptionalFeature -Online -FeatureName $feature.FeatureName).State
        Write-Host ("{0,3}. {1,-40} - {2} (Status: {3})" -f ($i + 1), $feature.Name, $feature.Description, $status)
    }
    Write-Host "`nq. Powrót do głównego menu`n"
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
        Write-Host "Uwaga: Nie wszystkie pakiety Chocolatey wspierają niestandardową ścieżkę instalacji." -ForegroundColor Yellow
    }

    Write-Host "Wykonywanie polecenia: choco $($chocoArgs -join ' ')" -ForegroundColor Cyan
    try {
        $process = Start-Process choco -ArgumentList $chocoArgs -Wait -PassThru -NoNewWindow
        if ($process.ExitCode -eq 0) {
            Write-Host "Polecenie wykonane pomyślnie." -ForegroundColor Green
        }
        else {
            Write-Host "Polecenie zakończyło się błędem (kod wyjścia: $($process.ExitCode))." -ForegroundColor Red
        }
    }
    catch {
        Write-Host "Wystąpił krytyczny błąd podczas wykonywania polecenia choco." -ForegroundColor Red
        Write-Host "Szczegóły: $($_.Exception.Message)"
    }
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
    
    # Tworzymy spłaszczoną listę, która jest potrzebna do łatwego wyboru programu po numerze.
    $allApps = [System.Collections.Generic.List[object]]::new()
    foreach ($category in $appsData) {
        if ($null -ne $category.Apps) {
            $allApps.AddRange($category.Apps)
        }
    }

    do {
        Clear-Host
        Write-Host "`n==== Główne Menu ====`n" -ForegroundColor Yellow
        Write-Host "1. Zarządzaj programami (instalacja/deinstalacja)"
        Write-Host "2. Zarządzaj funkcjami Windows (włączanie/wyłączanie)"
        Write-Host "q. Zakończ"

        $mainChoice = Read-Host "Wybierz opcję"

        switch ($mainChoice) {
            "1" {
                do {
                    Clear-Host
                    $appChoice = Show-AppsMenu -appsData $appsData
                    if ($appChoice -eq "q") { break }

                    if ($appChoice -match "^\d+$" -and [int]$appChoice -gt 0 -and [int]$appChoice -le $allApps.Count) {
                        $selectedIndex = [int]$appChoice - 1
                        $selectedApp = $allApps[$selectedIndex]
                        
                        Write-Host "`nWybrano: $($selectedApp.Name)" -ForegroundColor Yellow
                        Write-Host "1. Zainstaluj"
                        Write-Host "2. Odinstaluj"
                        $actionChoice = Read-Host "Wybierz akcję"

                        if ($actionChoice -eq "1") {
                            $pathChoice = Read-Host "Czy chcesz podać niestandardową ścieżkę instalacji? (y/n)"
                            $customPath = ""
                            if ($pathChoice -eq 'y') {
                                $customPath = Read-Host "Podaj pełną ścieżkę instalacji (np. D:\Programy)"
                            }
                            Invoke-ChocoCommand -Command "install" -PackageId $selectedApp.ChocoId -InstallPath $customPath
                        }
                        elseif ($actionChoice -eq "2") {
                            Invoke-ChocoCommand -Command "uninstall" -PackageId $selectedApp.ChocoId
                        }
                        else {
                            Write-Host "Nieprawidłowy wybór." -ForegroundColor Red
                        }
                    }
                    else {
                        Write-Host "Nieprawidłowy numer. Spróbuj ponownie." -ForegroundColor Red
                    }
                    Read-Host "Naciśnij Enter, aby kontynuować..."
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
                        
                        try {
                            switch ($actionChoice) {
                                "1" {
                                    Write-Host "`nWłączam funkcję $($selectedFeature.Name)..." -ForegroundColor Cyan
                                    Enable-WindowsOptionalFeature -Online -FeatureName $selectedFeature.FeatureName -All -NoRestart
                                    Write-Host "Funkcja włączona. Może być wymagane ponowne uruchomienie komputera." -ForegroundColor Green
                                }
                                "2" {
                                    Write-Host "`nWyłączam funkcję $($selectedFeature.Name)..." -ForegroundColor Cyan
                                    Disable-WindowsOptionalFeature -Online -FeatureName $selectedFeature.FeatureName -NoRestart
                                    Write-Host "Funkcja wyłączona. Może być wymagane ponowne uruchomienie komputera." -ForegroundColor Green
                                }
                                default {
                                    Write-Host "Nieprawidłowy wybór." -ForegroundColor Red
                                }
                            }
                        }
                        catch {
                             Write-Host "Wystąpił błąd podczas zmiany statusu funkcji." -ForegroundColor Red
                             Write-Host "Szczegóły: $($_.Exception.Message)"
                        }
                    }
                    else {
                        Write-Host "Nieprawidłowy numer. Spróbuj ponownie." -ForegroundColor Red
                    }
                    Read-Host "Naciśnij Enter, aby kontynuować..."
                } while ($true)
            }
            "q" {
                Write-Host "Zamykanie narzędzia. Do widzenia!"
                return
            }
            default {
                Write-Host "Nieprawidłowy wybór. Spróbuj ponownie." -ForegroundColor Red
                Read-Host "Naciśnij Enter, aby kontynuować..."
            }
        }
    } while ($true)
}

# endregion

# Uruchomienie skryptu
Check-Admin
Check-Chocolatey
Main-Menu
