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
# Wersja: 4.8 - Scentralizowano definicje kolorów dla łatwej personalizacji.

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
$
