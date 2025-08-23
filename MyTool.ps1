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
# Wersja: 5.1 - Dodano interaktywne wyszukiwanie z autouzupełnianiem.

# region Konfiguracja protokołu sieciowego
# Wymusza użycie TLS 1.2, co jest wymagane przez nowoczesne serwery (np. GitHub).
# Ta linia rozwiązuje problem z połączeniem przy pobieraniu skryptu i jego danych.
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12
# endregion

# region Zmiana kolorów konsoli
# Ustawia tło na czarne i tekst na biały, aby zapewnić spójny wygląd.
$Host.UI.RawUI.BackgroundColor = "Black"
$Host.UI.RawUI.ForegroundColor = "Cyan"
Clear-Host
# endregion

# region Definicje kolorów
# Centralne miejsce do zarządzania kolorami w skrypcie.
# Zmień poniższe wartości, aby dostosować wygląd całego narzędzia.
$colors = @{
    Error       = "Red"     # Kolor dla komunikatów o błędach.
    Success     = "Green"   # Kolor dla komunikatów o powodzeniu (np. numery list, pomyślne zakończenie).
    Highlight   = "Blue"    # Kolor do podświetlania ważnych elementów (np. nazwy programów, tytuły menu).
    Header      = "DarkRed" # Kolor dla nagłówków sekcji i kategorii.
    Info        = "White"   # Kolor dla komunikatów informacyjnych (np. "Pobieram dane...").
    DefaultText = "Gray"    # Standardowy kolor tekstu (np. opisy programów).
}
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
        Write-Host "Ten skrypt musi być uruchomiony z uprawnieniami administratora." -ForegroundColor $colors.Error
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
    # Pobiera i parsuje plik JSON z GitHub.
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
    
    $count = 1 # Ogólny licznik dla numeracji programów

    foreach ($category in $appsData) {
        Write-Host "`n---- $($category.Category) ----" -ForegroundColor $colors.Header
        
        foreach ($app in $category.Apps) {
            # Formatowanie: Numer. Nazwa - Opis
            Write-Host ("{0,3}. " -f $count) -ForegroundColor $colors.Success -NoNewline
            Write-Host $app.Name -ForegroundColor $colors.Highlight -NoNewline
            Write-Host " - $($app.Description)" -ForegroundColor $colors.DefaultText
            $count++
        }
    }

    Write-Host "`ns. Wyszukaj program (z autouzupełnianiem)" -ForegroundColor $colors.Highlight
    Write-Host "q. Powrót do głównego menu`n"
    $choice = Read-Host "Wybierz numer programu, 's' aby wyszukać, lub numery po przecinku (np. 1,5,8)"
    return $choice
}

function Show-SearchResults($foundApps, $searchTerm) {
    if ($foundApps.Count -eq 0) {
        Write-Host "Brak wyników dla: '$searchTerm'" -ForegroundColor $colors.Error
        return
    }

    Write-Host "`nZnaleziono $($foundApps.Count) programów dla: '$searchTerm'`n" -ForegroundColor $colors.Success

    # Wyświetlenie wyników wyszukiwania
    for ($i = 0; $i -lt $foundApps.Count; $i++) {
        $foundApp = $foundApps[$i]
        Write-Host ("{0,3}. " -f ($i + 1)) -ForegroundColor $colors.Success -NoNewline
        Write-Host $foundApp.App.Name -ForegroundColor $colors.Highlight -NoNewline
        Write-Host " - $($foundApp.App.Description)" -ForegroundColor $colors.DefaultText
        Write-Host "     (Oryginalny numer: $($foundApp.OriginalIndex))" -ForegroundColor $colors.Info
    }
}

function Search-Apps-Interactive($allApps) {
    Write-Host "`n==== Interaktywne wyszukiwanie programów ====`n" -ForegroundColor $colors.Header
    Write-Host "Wpisuj kolejne litery, aby zawęzić wyniki wyszukiwania." -ForegroundColor $colors.Info
    Write-Host "Dostępne komendy:" -ForegroundColor $colors.Info
    Write-Host "- Wpisz litery/cyfry: wyszukiwanie" -ForegroundColor $colors.DefaultText
    Write-Host "- 'clear': wyczyść wyszukiwanie" -ForegroundColor $colors.DefaultText
    Write-Host "- 'select': wybierz programy z aktualnych wyników" -ForegroundColor $colors.DefaultText
    Write-Host "- 'q': powrót do menu`n" -ForegroundColor $colors.DefaultText

    $searchTerm = ""
    $foundApps = [System.Collections.Generic.List[object]]::new()

    # Inicjalne wyświetlenie - wszystkie programy
    for ($i = 0; $i -lt $allApps.Count; $i++) {
        $foundApps.Add(@{
            App = $allApps[$i]
            OriginalIndex = $i + 1
        })
    }

    while ($true) {
        Clear-Host
        Write-Host "`n==== Interaktywne wyszukiwanie programów ====`n" -ForegroundColor $colors.Header
        Write-Host "Aktualne wyszukiwanie: '$searchTerm'" -ForegroundColor $colors.Highlight
        
        Show-SearchResults -foundApps $foundApps -searchTerm $searchTerm
        
        Write-Host "`nWpisz kolejne litery, 'clear', 'select' lub 'q':" -ForegroundColor $colors.Info
        $input = Read-Host

        switch ($input.ToLower()) {
            "q" {
                return $null
            }
            "clear" {
                $searchTerm = ""
                $foundApps.Clear()
                for ($i = 0; $i -lt $allApps.Count; $i++) {
                    $foundApps.Add(@{
                        App = $allApps[$i]
                        OriginalIndex = $i + 1
                    })
                }
            }
            "select" {
                if ($foundApps.Count -eq 0) {
                    Write-Host "Brak wyników do wyboru." -ForegroundColor $colors.Error
                    Read-Host "Naciśnij Enter, aby kontynuować..."
                    continue
                }
                
                Write-Host "`nWybierz numery z aktualnych wyników (np. 1,3,5):" -ForegroundColor $colors.Highlight
                $choice = Read-Host
                
                if ([string]::IsNullOrWhiteSpace($choice)) {
                    continue
                }

                # Konwersja wyborów z wyników wyszukiwania na oryginalne numery
                $searchChoices = $choice.Split(',')
                $originalNumbers = [System.Collections.Generic.List[string]]::new()
                
                foreach ($searchChoice in $searchChoices) {
                    $trimmedChoice = $searchChoice.Trim()
                    if ($trimmedChoice -match "^\d+$" -and [int]$trimmedChoice -gt 0 -and [int]$trimmedChoice -le $foundApps.Count) {
                        $selectedIndex = [int]$trimmedChoice - 1
                        $originalNumbers.Add($foundApps[$selectedIndex].OriginalIndex.ToString())
                    }
                    else {
                        Write-Host "Pominięto nieprawidłowy numer: '$($trimmedChoice)'" -ForegroundColor $colors.Error
                    }
                }

                if ($originalNumbers.Count -gt 0) {
                    return ($originalNumbers -join ',')
                }
                else {
                    Write-Host "Nie wybrano żadnych prawidłowych programów." -ForegroundColor $colors.Error
                    Read-Host "Naciśnij Enter, aby kontynuować..."
                }
            }
            default {
                # Dodanie nowych znaków do wyszukiwania
                if (-not [string]::IsNullOrWhiteSpace($input)) {
                    $searchTerm += $input
                    
                    # Aktualizacja wyników wyszukiwania
                    $foundApps.Clear()
                    for ($i = 0; $i -lt $allApps.Count; $i++) {
                        $app = $allApps[$i]
                        if ($app.Name -like "*$searchTerm*" -or $app.Description -like "*$searchTerm*") {
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

function Show-FeaturesMenu($features) {
    # Wyświetla menu funkcji Windows.
    Write-Host "`n==== Zarządzanie funkcjami Windows ====`n" -ForegroundColor $colors.Header
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

function Main-Menu {
    # Główna pętla menu.
    $appsData = Get-JsonData "apps.json"
    $featuresData = Get-JsonData "features.json"

    if (-not $appsData -or -not $featuresData) {
        Write-Host "Nie można kontynuować z powodu błędów pobierania danych konfiguracyjnych." -ForegroundColor $colors.Error
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
        Write-Host "`n==== Główne Menu ====`n" -ForegroundColor $colors.Highlight
        Write-Host "1. Zarządzaj programami (instalacja/deinstalacja)"
        Write-Host "2. Zarządzaj funkcjami Windows (włączanie/wyłączanie)"
        Write-Host "q. Zakończ"

        $mainChoice = Read-Host "Wybierz opcję"

        switch ($mainChoice) {
            "1" {
                do {
                    Clear-Host
                    $appChoiceString = Show-AppsMenu -appsData $appsData
                    if ($appChoiceString -eq "q") { break }

                    # Obsługa wyszukiwania
                    if ($appChoiceString -eq "s") {
                        $searchResult = Search-Apps-Interactive -allApps $allApps
                        if ($null -ne $searchResult) {
                            $appChoiceString = $searchResult
                        }
                        else {
                            continue  # Powrót do menu jeśli wyszukiwanie nie zwróciło wyników
                        }
                    }

                    # Dzielimy wpisany tekst na pojedyncze numery
                    $appChoices = $appChoiceString.Split(',')

                    if ($appChoices.Count -gt 0 -and $appChoiceString) {
                        Write-Host "`nWybrano numery: $($appChoiceString)" -ForegroundColor $colors.Highlight
                        Write-Host "1. Zainstaluj"
                        Write-Host "2. Odinstaluj"
                        $actionChoice = Read-Host "Wybierz akcję dla wszystkich wybranych programów"

                        # Pytanie o ścieżkę przed pętlą, dla wszystkich programów jednocześnie
                        $customPath = ""
                        if ($actionChoice -eq "1") {
                            $pathChoice = Read-Host "Czy chcesz podać niestandardową ścieżkę instalacji dla wszystkich programów? (y/n)"
                            if ($pathChoice -eq 'y') {
                                $customPath = Read-Host "Podaj pełną ścieżkę instalacji (np. D:\Programy)"
                            }
                        }

                        # Pętla przez każdy wybrany numer
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
                                    break # Przerywamy pętlę, jeśli wybór akcji był zły
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
                Write-Host "Zamykanie narzędzia. Do widzenia!"
                return
            }
            default {
                Write-Host "Nieprawidłowy wybór. Spróbuj ponownie." -ForegroundColor $colors.Error
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
