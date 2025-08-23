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
# Wersja: 4.9 - Dodano możliwość instalacji/deinstalacji wielu programów jednocześnie.

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

    Write-Host "`nq. Powrót do głównego menu`n"
    # ZMIANA: Zaktualizowano treść pytania, aby umożliwić wybór wielu programów.
    $choice = Read-Host "Wybierz numery programów (oddzielone przecinkami, np. 1,5,8)"
    return $choice
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
        # ZMIANA: $PackageId może teraz przyjąć wiele ID oddzielonych spacją.
        [string]$PackageIds,
        [string]$InstallPath = ""
    )
    
    # ZMIANA: Argumenty są teraz budowane w oparciu o $PackageIds.
    $chocoArgs = @($Command, $PackageIds, "-y")
    if ($Command -eq "install" -and -not [string]::IsNullOrEmpty($InstallPath)) {
        # Uwaga: niestandardowa ścieżka ma sens tylko przy instalacji jednego pakietu.
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
                    $appChoiceInput = Show-AppsMenu -appsData $appsData
                    if ($appChoiceInput -eq "q") { break }

                    # ZMIANA: Całkowicie nowa logika do obsługi wielu wyborów.
                    $selectedApps = @()
                    $invalidChoices = @()
                    
                    $choices = $appChoiceInput.Split(',') | ForEach-Object { $_.Trim() }

                    foreach ($choice in $choices) {
                        if ($choice -match "^\d+$" -and [int]$choice -gt 0 -and [int]$choice -le $allApps.Count) {
                            $selectedIndex = [int]$choice - 1
                            $selectedApps += $allApps[$selectedIndex]
                        }
                        else {
                            $invalidChoices += $choice
                        }
                    }

                    if ($invalidChoices.Count -gt 0) {
                        Write-Host "Pominięto nieprawidłowe wybory: $($invalidChoices -join ', ')" -ForegroundColor $colors.Error
                    }

                    if ($selectedApps.Count -gt 0) {
                        Write-Host "`nWybrano następujące programy:" -ForegroundColor $colors.Highlight
                        $selectedApps.Name | ForEach-Object { Write-Host "- $_" }
                        
                        Write-Host "`n1. Zainstaluj"
                        Write-Host "2. Odinstaluj"
                        $actionChoice = Read-Host "Wybierz akcję dla wybranych programów"
                        
                        $packageIds = ($selectedApps.ChocoId) -join ' '
                        
                        if ($actionChoice -eq "1") {
                            $customPath = ""
                            if ($selectedApps.Count -eq 1) {
                                $pathChoice = Read-Host "Czy chcesz podać niestandardową ścieżkę instalacji? (y/n)"
                                if ($pathChoice -eq 'y') {
                                    $customPath = Read-Host "Podaj pełną ścieżkę instalacji (np. D:\Programy)"
                                }
                            }
                            Invoke-ChocoCommand -Command "install" -PackageIds $packageIds -InstallPath $customPath
                        }
                        elseif ($actionChoice -eq "2") {
                            Invoke-ChocoCommand -Command "uninstall" -PackageIds $packageIds
                        }
                        else {
                            Write-Host "Nieprawidłowy wybór akcji." -ForegroundColor $colors.Error
                        }
                    }
                    else {
                        Write-Host "Nie wybrano żadnych prawidłowych programów." -ForegroundColor $colors.Error
                    }
                    # KONIEC ZMIANY

                    Read-Host "Naciśnij Enter, aby kontynuować..."
                } while ($
