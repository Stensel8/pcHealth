# ============================================================================
# pcHealth - Windows 11 - V1.9.1
# ============================================================================
# Windows Product Key Grabber (CLI — launches WPF GUI)
# Extracts the Windows product key via OA3 (UEFI/BIOS) and registry decode.
# For legacy systems, use the VBS version in Windows 10/CLI.
# ============================================================================

Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase

# ============================================================================
# GENERIC KEY DATABASE
# ============================================================================
# These are KMS client setup keys (GVLK) - basically Windows' "demo mode" keys.
# If you find one of these, congrats; You found a placeholder key that won't
# actually activate Windows. Time to dig deeper or check that sticker!
# ============================================================================
$GenericKeys = @{
    'VK7JG-NPHTM-C97JM-9MPGT-3V66T' = 'Windows 11 Pro'
    'YTMG3-N6DKC-DKB77-7M9GH-8HVX7' = 'Windows 11 Pro N'
    'YNMGQ-8RYV3-4PGQ3-C8XTP-7CFBY' = 'Windows 11 Home'
    'TX9XD-98N7V-6WMQ6-BX7FG-H8Q99' = 'Windows 11 Home N'
    'NPPR9-FWDCX-D2C8J-H872K-2YT43' = 'Windows 11 Enterprise'
    'NRG8B-VKK3Q-CXVCJ-9G2XF-6Q84J' = 'Windows 11 Pro for Workstations'
    'W269N-WFGWX-YVC9B-4J6C9-T83GX' = 'Windows 10/11 Pro'
}

# ============================================================================
# FUNCTION: Get-SystemTheme
# ============================================================================
# Detects whether Windows is in Dark or Light mode by reading the registry.
#
# REGISTRY PATH:
# HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize
#
# REGISTRY VALUE:
# AppsUseLightTheme: 0 = Dark Mode, 1 = Light Mode
#
# RETURN: "Dark" or "Light"
# ============================================================================
function Get-SystemTheme {
    try {
        $RegPath = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize"
        $AppsTheme = Get-ItemProperty -Path $RegPath -Name AppsUseLightTheme -ErrorAction SilentlyContinue
        if ($null -eq $AppsTheme -or $AppsTheme.AppsUseLightTheme -eq 1) { return "Light" }
        return "Dark"
    } catch {
        return "Light"
    }
}

# ============================================================================
# FUNCTION: Get-ProductKeyFromDigitalProductId
# ============================================================================
# Decodes the DigitalProductId registry value into a readable product key.
#
# ALGORITHM: Base24 Encoding
# Windows stores product keys in the registry as a binary array. The key is
# encoded using a custom Base24 algorithm that uses 24 characters (excluding
# vowels and certain numbers to avoid confusion/profanity).
#
# CHARACTER SET: "BCDFGHJKMPQRTVWXY2346789" (24 chars)
# - No vowels (A, E, I, O, U) to avoid offensive words
# - No 0, 1, 5 to avoid confusion with O, I, S
#
# REGISTRY LOCATION:
# HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\DigitalProductId
#
# DATA STRUCTURE:
# - Bytes 0-51: Header information
# - Bytes 52-66: Encoded product key (15 bytes)
# - Bytes 67+: Additional data
#
# DECODING PROCESS:
# 1. Extract bytes 52-66 (15 bytes containing the encoded key)
# 2. Perform Base24 division on these bytes (25 iterations)
# 3. Each division gives us one character from the charset
# 4. Add dashes every 5 characters for readability
#
# RETURN: Formatted product key (XXXXX-XXXXX-XXXXX-XXXXX-XXXXX) or $null
# ============================================================================
function Get-ProductKeyFromDigitalProductId {
    try {
        $RegPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion"
        $DigitalProductId = (Get-ItemProperty -Path $RegPath -ErrorAction Stop).DigitalProductId

        if (-not $DigitalProductId) {
            Write-Host "  DEBUG: DigitalProductId is null/empty" -ForegroundColor Yellow
            return $null
        }

        Write-Host "  DEBUG: DigitalProductId found, length: $($DigitalProductId.Length) bytes" -ForegroundColor Green

        # Extract the key portion (bytes 52-66 = 15 bytes)
        $key = $DigitalProductId[52..66]

        # Base24 character set
        $chars = "BCDFGHJKMPQRTVWXY2346789"
        $productKey = ""

        # Check for Windows 8+ key (has special N-character encoding)
        $isWin8Plus = ($key[14] -shr 3) -band 1
        $key[14] = ($key[14] -band 0xF7) -bor (($isWin8Plus -band 2) -shl 2)

        # Decode the key
        for ($i = 24; $i -ge 0; $i--) {
            $cur = 0
            for ($j = 14; $j -ge 0; $j--) {
                $cur = ($cur -shl 8) -bor $key[$j]
                $key[$j] = [math]::Floor($cur / 24)
                $cur = $cur % 24
            }
            $productKey = $chars[$cur] + $productKey
        }

        # Insert 'N' for Windows 8+ keys
        if ($isWin8Plus) {
            $firstChar = $productKey[0]
            $nIndex = 0
            for ($i = 0; $i -lt $chars.Length; $i++) {
                if ($chars[$i] -eq $firstChar) {
                    $nIndex = $i
                    break
                }
            }
            $productKey = $productKey.Substring(1)
            $productKey = $productKey.Insert($nIndex, "N")
        }

        # Format with dashes
        $formattedKey = ""
        for ($i = 0; $i -lt 25; $i++) {
            $formattedKey += $productKey[$i]
            if (($i + 1) % 5 -eq 0 -and $i -lt 24) {
                $formattedKey += "-"
            }
        }

        Write-Host "  DEBUG: Decoded key: $formattedKey" -ForegroundColor Green
        return $formattedKey
    } catch {
        Write-Host "  DEBUG: Error in DigitalProductId: $($_.Exception.Message)" -ForegroundColor Red
        return $null
    }
}

# ============================================================================
# FUNCTION: Get-ProductKeyFromOA3
# ============================================================================
# Retrieves the OEM Activation 3.0 product key from UEFI/BIOS firmware.
#
# BACKGROUND:
# Starting with Windows 8, OEMs embed product keys directly in the UEFI/BIOS
# firmware instead of using stickers. This is called OA3 (OEM Activation 3.0).
#
# ADVANTAGES:
# - Key survives OS reinstalls
# - No physical sticker that can wear off
# - Automatic activation on first boot
#
# RETRIEVAL METHOD:
# Uses CIM to query the SoftwareLicensingService class which reads
# the OA3xOriginalProductKey property from UEFI firmware.
#
# NOTE:
# This will return $null on:
# - Non-OEM systems (custom built PCs)
# - Systems activated with retail keys
# - Systems using Volume Licensing (KMS/MAK)
# - Pre-Windows 8 systems
#
# RETURN: Product key string or $null
# ============================================================================
function Get-ProductKeyFromOA3 {
    try {
        Write-Host "  DEBUG: Querying SoftwareLicensingService..." -ForegroundColor Cyan
        $key = (Get-CimInstance -Query 'SELECT * FROM SoftwareLicensingService' -ErrorAction Stop).OA3xOriginalProductKey
        if ($key) { Write-Host "  DEBUG: OA3 key found: $key" -ForegroundColor Green; return $key }
        Write-Host "  DEBUG: OA3xOriginalProductKey is null (not an OEM system)" -ForegroundColor Yellow
    } catch {
        Write-Host "  DEBUG: OA3 query failed: $($_.Exception.Message)" -ForegroundColor Red
    }
    return $null
}

# ============================================================================
# FUNCTION: Get-WindowsVersion
# ============================================================================
# Gets Windows version info using native CIM for best accuracy.
#
# Uses Win32_OperatingSystem.Caption for the OS name - this is the proper
# Windows API way to get the friendly product name (e.g., "Microsoft Windows 11 Pro")
# instead of trying to build it manually from registry EditionID values.
#
# This automatically handles all Windows editions correctly:
# - Client: Home, Pro, Enterprise, Education, etc.
# - Server: Standard, Datacenter, Essentials, etc.
# - Special: Eval versions, LTSC, N editions, etc.
# ============================================================================
function Get-WindowsVersion {
    try {
        $OS = Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction Stop
        $ProductID = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion").ProductID

        return @{
            Name = $OS.Caption       # Native OS name from Windows API
            Build = $OS.BuildNumber  # Build number
            ProductID = $ProductID
        }
    }
    catch {
        Write-Host "  ERROR: Failed to retrieve Windows version: $($_.Exception.Message)" -ForegroundColor Red
        return @{ Name = "Unknown Windows Version"; Build = "Unknown"; ProductID = "Unknown" }
    }
}

# ============================================================================
# FUNCTION: Test-ProductKeyFormat
# ============================================================================
# Validates product key format (not activation status).
#
# VALID FORMAT: XXXXX-XXXXX-XXXXX-XXXXX-XXXXX
# - 5 groups of 5 characters
# - Separated by dashes
# - Only uses valid Base24 characters: BCDFGHJKMPQRTVWXY2346789
#
# NOTE: This only checks FORMAT, not whether the key is genuine or activated.
# A properly formatted generic key will pass this check.
#
# RETURN: $true if format is valid, $false otherwise
# ============================================================================
function Test-ProductKeyFormat {
    param([string]$Key)
    if ([string]::IsNullOrEmpty($Key)) { return $false }
    # Check for standard format: XXXXX-XXXXX-XXXXX-XXXXX-XXXXX
    # OA3 keys can use any alphanumeric characters, not just Base24
    if ($Key -notmatch '^[A-Z0-9]{5}-[A-Z0-9]{5}-[A-Z0-9]{5}-[A-Z0-9]{5}-[A-Z0-9]{5}$') { return $false }
    return $true
}

# ============================================================================
# FUNCTION: Invoke-AllKeyMethods
# ============================================================================
# Attempts to retrieve the product key using all available methods.
# Tracks which methods succeed/fail for display in the results table.
#
# METHODS ATTEMPTED:
# 1. OA3xOriginalProductKey (UEFI/BIOS firmware) - Original manufacturer key
# 2. DigitalProductId (Registry decode) - Currently active key
#
# KEY SELECTION PRIORITY:
# - Registry key (current/active) is preferred over OA3 key (original)
# - Multiple different keys indicate an upgraded system
# - Registry key is most reliable for re-activation
# ============================================================================
function Invoke-AllKeyMethods {
    $methods = @()

    # METHOD 1: OA3 (UEFI/BIOS) - Plaintext readout
    Write-Host "Attempting Method 1: OA3 (UEFI/BIOS)..." -ForegroundColor Cyan
    $oa3Key = Get-ProductKeyFromOA3
    if ($oa3Key -and (Test-ProductKeyFormat $oa3Key)) {
        $methods += @{ Name = "OA3 (UEFI/BIOS) - Plaintext"; Status = "Success"; Result = $oa3Key; Icon = "[+]" }
    } else {
        $methods += @{ Name = "OA3 (UEFI/BIOS) - Plaintext"; Status = "Failed"; Result = "N/A"; Icon = "[-]" }
    }

    # METHOD 2: DigitalProductId (Registry) - Decoded with reverse-engineered algorithm
    Write-Host "Attempting Method 2: DigitalProductId (Registry)..." -ForegroundColor Cyan
    $regKey = Get-ProductKeyFromDigitalProductId
    if ($regKey -and (Test-ProductKeyFormat $regKey)) {
        $methods += @{ Name = "DigitalProductId (Registry) - Decoded"; Status = "Success"; Result = $regKey; Icon = "[+]" }
    } else {
        $methods += @{ Name = "DigitalProductId (Registry) - Decoded"; Status = "Failed"; Result = "N/A"; Icon = "[-]" }
    }

    # Select best key (prefer Registry over OA3)
    $bestKey = if ($regKey) { $regKey } elseif ($oa3Key) { $oa3Key } else { $null }
    $bestSource = if ($regKey) { "Registry (DigitalProductId)" } elseif ($oa3Key) { "UEFI/BIOS Firmware (OA3)" } else { "None" }

    return @{ BestKey = $bestKey; Source = $bestSource; Methods = $methods }
}

# ============================================================================
# MAIN EXECUTION
# ============================================================================

Write-Host "`n========================================" -ForegroundColor Green
Write-Host "pcHealth | Windows Key Grabber" -ForegroundColor Green
Write-Host "========================================`n" -ForegroundColor Green

# Get Windows version and attempt all key extraction methods
$WinVersion = Get-WindowsVersion
Write-Host "Detected: $($WinVersion.Name) (Build $($WinVersion.Build))`n" -ForegroundColor Yellow
$results = Invoke-AllKeyMethods
$ProductKey, $KeySource, $MethodResults = $results.BestKey, $results.Source, $results.Methods

# Check if key is generic
$IsGenericKey = $ProductKey -and $GenericKeys.ContainsKey($ProductKey)
$GenericKeyType = if ($IsGenericKey) { $GenericKeys[$ProductKey] } else { "" }
if ($IsGenericKey) { Write-Host "WARNING: Generic/Placeholder key detected!" -ForegroundColor Yellow }

# Detect system theme for UI colors
$Theme = Get-SystemTheme
Write-Host "System Theme: $Theme Mode`n" -ForegroundColor Cyan

# Define UI colors based on theme
$colors = if ($Theme -eq "Dark") {
    @{ BgColor = "#1E1E1E"; FgColor = "#FFFFFF"; BorderColor = "#3F3F46"; HeaderBg = "#2D2D30"
       SuccessBg = "#0D3B26"; SuccessFg = "#4ADE80"; ErrorBg = "#3B0D0D"; ErrorFg = "#F87171"
       WarningBg = "#3B2D0D"; WarningFg = "#FACC15" }
} else {
    @{ BgColor = "#FFFFFF"; FgColor = "#000000"; BorderColor = "#E4E4E7"; HeaderBg = "#F4F4F5"
       SuccessBg = "#DCFCE7"; SuccessFg = "#15803D"; ErrorBg = "#FEE2E2"; ErrorFg = "#DC2626"
       WarningBg = "#FEF3C7"; WarningFg = "#CA8A04" }
}
$BgColor, $FgColor, $BorderColor, $HeaderBg = $colors.BgColor, $colors.FgColor, $colors.BorderColor, $colors.HeaderBg
$SuccessBg, $SuccessFg, $ErrorBg, $ErrorFg = $colors.SuccessBg, $colors.SuccessFg, $colors.ErrorBg, $colors.ErrorFg
$WarningBg, $WarningFg = $colors.WarningBg, $colors.WarningFg

# ============================================================================
# GUI CONSTRUCTION (WPF XAML)
# ============================================================================

[xml]$xaml = @"
<Window
    xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
    xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
    Title="pcHealth | Windows Key Grabber"
    Width="720" Height="720"
    MinWidth="600" MinHeight="600"
    WindowStartupLocation="CenterScreen"
    Background="$BgColor"
    ResizeMode="CanResize">
    
    <Grid Margin="20">
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
        </Grid.RowDefinitions>
        
        <!-- Header -->
        <Border Grid.Row="0" Background="$HeaderBg" Padding="15" CornerRadius="6" Margin="0,0,0,15">
            <Grid>
                <Grid.RowDefinitions>
                    <RowDefinition Height="Auto"/>
                    <RowDefinition Height="Auto"/>
                </Grid.RowDefinitions>
                <TextBlock Grid.Row="0" Text="Windows Product Key Grabber"
                           FontSize="20" FontWeight="Bold" Foreground="$FgColor"/>
                <TextBlock Grid.Row="1" Text="pcHealth"
                           FontSize="11" Foreground="$FgColor" Opacity="0.7" Margin="0,5,0,0"/>
            </Grid>
        </Border>
        
        <!-- System Info -->
        <Border Grid.Row="1" BorderBrush="$BorderColor" BorderThickness="1" 
                Padding="12" CornerRadius="6" Margin="0,0,0,15">
            <Grid>
                <Grid.RowDefinitions>
                    <RowDefinition Height="Auto"/>
                    <RowDefinition Height="Auto"/>
                    <RowDefinition Height="Auto"/>
                </Grid.RowDefinitions>
                <Grid.ColumnDefinitions>
                    <ColumnDefinition Width="140"/>
                    <ColumnDefinition Width="*"/>
                </Grid.ColumnDefinitions>
                
                <!-- Row 1: Windows Version -->
                <TextBlock Grid.Row="0" Grid.Column="0" Text="Windows Version:" 
                           Foreground="$FgColor" Opacity="0.7" FontSize="11"/>
                <TextBlock Grid.Row="0" Grid.Column="1" Name="txtWinVersion"
                           Foreground="$FgColor" FontSize="11" FontWeight="Medium"/>
                
                <!-- Row 2: Product ID -->
                <TextBlock Grid.Row="1" Grid.Column="0" Text="Product ID:" 
                           Foreground="$FgColor" Opacity="0.7" FontSize="11" Margin="0,5,0,0"/>
                <TextBlock Grid.Row="1" Grid.Column="1" Name="txtProductID"
                           Foreground="$FgColor" FontSize="11" FontWeight="Medium" Margin="0,5,0,0"/>
                
                <!-- Row 3: Key Source -->
                <TextBlock Grid.Row="2" Grid.Column="0" Text="Key Source:" 
                           Foreground="$FgColor" Opacity="0.7" FontSize="11" Margin="0,5,0,0"/>
                <TextBlock Grid.Row="2" Grid.Column="1" Name="txtKeySource"
                           Foreground="$FgColor" FontSize="11" FontWeight="Medium" Margin="0,5,0,0"/>
            </Grid>
        </Border>
        
        <!-- Product Key Display -->
        <Border Grid.Row="2" BorderBrush="$BorderColor" BorderThickness="2"
                Padding="20" CornerRadius="8" Margin="0,0,0,15" Background="$HeaderBg">
            <Grid>
                <Grid.RowDefinitions>
                    <RowDefinition Height="Auto"/>
                    <RowDefinition Height="Auto"/>
                </Grid.RowDefinitions>
                <TextBlock Grid.Row="0" Text="Primary Product Key"
                           FontSize="12" FontWeight="SemiBold" Foreground="$FgColor" Opacity="0.7"/>
                <TextBlock Grid.Row="1" Name="txtProductKey"
                           FontSize="22" FontFamily="Consolas" FontWeight="Bold"
                           Foreground="$FgColor" Margin="0,8,0,0" TextAlignment="Center"/>
            </Grid>
        </Border>
        
        <!-- Extraction Methods Section Header -->
        <TextBlock Grid.Row="3" Text="All Extraction Methods &amp; Keys Found"
                   FontSize="14" FontWeight="SemiBold" Foreground="$FgColor" Margin="0,5,0,10"/>
        
        <!-- Extraction Methods Table -->
        <Border Grid.Row="4" BorderBrush="$BorderColor" BorderThickness="1" 
                CornerRadius="6" Margin="0,0,0,15">
            <Grid Margin="12">
                <Grid.RowDefinitions>
                    <RowDefinition Height="Auto"/>
                    <RowDefinition Height="Auto"/>
                    <RowDefinition Height="Auto"/>
                </Grid.RowDefinitions>

                <!-- Header Row -->
                <Grid Grid.Row="0" Margin="0,0,0,10">
                    <Grid.ColumnDefinitions>
                        <ColumnDefinition Width="40"/>
                        <ColumnDefinition Width="220"/>
                        <ColumnDefinition Width="100"/>
                        <ColumnDefinition Width="*"/>
                    </Grid.ColumnDefinitions>
                    <TextBlock Grid.Column="1" Text="METHOD" FontSize="10" FontWeight="Bold"
                               Foreground="$FgColor" Opacity="0.5"/>
                    <TextBlock Grid.Column="2" Text="STATUS" FontSize="10" FontWeight="Bold"
                               Foreground="$FgColor" Opacity="0.5"/>
                    <TextBlock Grid.Column="3" Text="PRODUCT KEY" FontSize="10" FontWeight="Bold"
                               Foreground="$FgColor" Opacity="0.5"/>
                </Grid>

                <!-- Method Rows (dynamically populated) -->
                <Border Grid.Row="1" Name="row1" Padding="0,8"/>
                <Border Grid.Row="2" Name="row2" Padding="0,8"/>
            </Grid>
        </Border>
        
        <!-- Status Message Box -->
        <Border Grid.Row="5" Name="msgBox" BorderThickness="1"
                Padding="15" CornerRadius="6" Margin="0,0,0,15">
            <Grid>
                <Grid.RowDefinitions>
                    <RowDefinition Height="Auto"/>
                    <RowDefinition Height="*"/>
                </Grid.RowDefinitions>
                <TextBlock Grid.Row="0" Name="msgTitle" FontSize="13" FontWeight="SemiBold" Margin="0,0,0,8"/>
                <ScrollViewer Grid.Row="1" VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Disabled">
                    <TextBlock Name="msgBody" FontSize="11" TextWrapping="Wrap" LineHeight="16"/>
                </ScrollViewer>
            </Grid>
        </Border>
        
        <!-- Action Buttons -->
        <Grid Grid.Row="7">
            <Grid.ColumnDefinitions>
                <ColumnDefinition Width="*"/>
                <ColumnDefinition Width="*"/>
                <ColumnDefinition Width="*"/>
            </Grid.ColumnDefinitions>
            
            <Button Grid.Column="0" Name="btnCopy" Content="Copy Key"
                    Padding="12,8" FontSize="12" Margin="0,0,5,0"
                    Background="$HeaderBg" Foreground="$FgColor" BorderBrush="$BorderColor"/>
            <Button Grid.Column="1" Name="btnSave" Content="Save Report"
                    Padding="12,8" FontSize="12" Margin="5,0,5,0"
                    Background="$HeaderBg" Foreground="$FgColor" BorderBrush="$BorderColor"/>
            <Button Grid.Column="2" Name="btnClose" Content="Close"
                    Padding="12,8" FontSize="12" Margin="5,0,0,0"
                    Background="$HeaderBg" Foreground="$FgColor" BorderBrush="$BorderColor"/>
        </Grid>
    </Grid>
</Window>
"@

# Load XAML
$reader = New-Object System.Xml.XmlNodeReader $xaml
$Window = [Windows.Markup.XamlReader]::Load($reader)

# Get named elements
$txtWinVersion = $Window.FindName("txtWinVersion")
$txtProductID = $Window.FindName("txtProductID")
$txtKeySource = $Window.FindName("txtKeySource")
$txtProductKey = $Window.FindName("txtProductKey")
$msgBox = $Window.FindName("msgBox")
$msgTitle = $Window.FindName("msgTitle")
$msgBody = $Window.FindName("msgBody")
$btnCopy = $Window.FindName("btnCopy")
$btnSave = $Window.FindName("btnSave")
$btnClose = $Window.FindName("btnClose")
$row1 = $Window.FindName("row1")
$row2 = $Window.FindName("row2")

# ============================================================================
# Populate UI with Data
# ============================================================================

# System info
$txtWinVersion.Text = "$($WinVersion.Name) (Build $($WinVersion.Build))"
$txtProductID.Text = $WinVersion.ProductID
$txtKeySource.Text = $KeySource

# Product key display
if ($ProductKey) {
    $txtProductKey.Text = $ProductKey
} else {
    $txtProductKey.Text = "No product key found"
    $txtProductKey.Opacity = 0.5
}

# Populate extraction methods table
$rows = @($row1, $row2)

for ($i = 0; $i -lt $MethodResults.Count -and $i -lt 2; $i++) {
    $method = $MethodResults[$i]
    $row = $rows[$i]

    $grid = New-Object System.Windows.Controls.Grid
    [void]$grid.ColumnDefinitions.Add((New-Object System.Windows.Controls.ColumnDefinition -Property @{Width="40"}))
    [void]$grid.ColumnDefinitions.Add((New-Object System.Windows.Controls.ColumnDefinition -Property @{Width="220"}))
    [void]$grid.ColumnDefinitions.Add((New-Object System.Windows.Controls.ColumnDefinition -Property @{Width="100"}))
    [void]$grid.ColumnDefinitions.Add((New-Object System.Windows.Controls.ColumnDefinition -Property @{Width="*"}))

    # Icon
    $icon = New-Object System.Windows.Controls.TextBlock
    $icon.Text = $method.Icon
    $icon.FontSize = 16
    $icon.Foreground = if ($method.Status -eq "Success") { $SuccessFg }
                      elseif ($method.Status -eq "Partial") { $WarningFg }
                      else { $ErrorFg }
    [System.Windows.Controls.Grid]::SetColumn($icon, 0)
    [void]$grid.Children.Add($icon)

    # Method Name
    $name = New-Object System.Windows.Controls.TextBlock
    $name.Text = $method.Name
    $name.Foreground = $FgColor
    $name.FontSize = 12
    [System.Windows.Controls.Grid]::SetColumn($name, 1)
    [void]$grid.Children.Add($name)

    # Status
    $status = New-Object System.Windows.Controls.TextBlock
    $status.Text = $method.Status
    $status.Foreground = if ($method.Status -eq "Success") { $SuccessFg }
                        elseif ($method.Status -eq "Partial") { $WarningFg }
                        else { $ErrorFg }
    $status.FontSize = 12
    $status.FontWeight = "SemiBold"
    [System.Windows.Controls.Grid]::SetColumn($status, 2)
    [void]$grid.Children.Add($status)

    # Result (Product Key)
    $result = New-Object System.Windows.Controls.TextBlock
    $result.Text = $method.Result
    $result.Foreground = $FgColor
    $result.FontFamily = "Consolas"
    $result.FontSize = 12
    $result.FontWeight = "Medium"
    $result.Opacity = 0.9
    [System.Windows.Controls.Grid]::SetColumn($result, 3)
    [void]$grid.Children.Add($result)

    $row.Child = $grid
}

# ============================================================================
# Display Status Message
# ============================================================================
$msgBox.Visibility = "Visible"

# Count successful key extractions
$successfulKeys = @($MethodResults | Where-Object { $_.Status -eq "Success" })
$multipleKeysFound = $successfulKeys.Count -gt 1

if ($ProductKey) {
    if ($IsGenericKey) {
        $msgBox.Background = $WarningBg
        $msgTitle.Foreground = $msgBody.Foreground = $WarningFg
        $msgTitle.Text = "WARNING: Generic/Placeholder Key Detected"
        $msgBody.Text = "This is a generic $GenericKeyType key used by OEMs and system integrators for pre-installation.`n`nThis key WILL NOT WORK for re-activation after a clean install!`n`nPOSSIBLE EXPLANATION (Not 100% certain):`nYour system may have been activated using unauthorized methods (e.g., AutoKMS, MassGravel scripts, or similar tools). These methods force Windows to accept non-genuine keys. We cannot be certain, but this is a common scenario.`n`nLEGITIMATE OPTIONS:`n`n1. Find your original product key:`n   - Sticker on your PC/laptop case`n   - Email receipt from purchase`n   - Digital license (linked to Microsoft account)`n`n2. Purchase a legitimate Windows 11 Pro RETAIL key:`n   - Search on key indexers like AllKeyShop`n   - Look for 'Windows 11 Pro Retail' keys`n   - AVOID OEM keys - they're for system builders only and won't work after Windows setup`n   - Retail keys can be transferred between computers"
    } elseif ($multipleKeysFound) {
        $msgBox.Background = $SuccessBg
        $msgTitle.Foreground = $msgBody.Foreground = $SuccessFg
        $msgTitle.Text = "Multiple Keys Found - Likely Upgraded System"
        $msgBody.Text = "Multiple product keys were detected, which typically indicates this system has been upgraded or re-activated with a different key.`n`nRECOMMENDATION: Use the DigitalProductId (Registry) key, as it represents the CURRENT key Windows is actively using. The OA3 key is the original manufacturer key that came with the device.`n`nNOTE: The Registry key is calculated using reverse-engineered algorithms and may be incorrect in some edge cases. Always verify the key works before relying on it."
    } else {
        $msgBox.Background = $SuccessBg
        $msgTitle.Foreground = $msgBody.Foreground = $SuccessFg
        $msgTitle.Text = "Valid Product Key"
        $msgBody.Text = "This key appears to be valid and can be used for Windows re-activation. Save it in a secure location for future use."
    }
} else {
    $msgBox.Background = $ErrorBg
    $msgTitle.Foreground = $msgBody.Foreground = $ErrorFg
    $msgTitle.Text = "No Product Key Found"
    $msgBody.Text = "No product key could be found in registry or UEFI firmware.`n`nThis may indicate:`n- Digital license (linked to Microsoft account)`n- Volume license (KMS/MAK activation)`n- Corrupted registry data"
}

# ============================================================================
# Button Event Handlers
# ============================================================================

# Copy Button - Copies the product key to clipboard
$btnCopy.Add_Click({
    if ($ProductKey) {
        Set-Clipboard -Value $ProductKey
        [System.Windows.MessageBox]::Show("Product key copied to clipboard!", "pcHealth | Copied", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information)
    }
})

# Save Button - Saves complete report to text file
$btnSave.Add_Click({
    if ($ProductKey -or $MethodResults.Count -gt 0) {
        $SaveDialog = New-Object Microsoft.Win32.SaveFileDialog
        $SaveDialog.Filter = "Text files (*.txt)|*.txt|All files (*.*)|*.*"
        $SaveDialog.FileName = "Windows-Key-Report-$(Get-Date -Format 'yyyy-MM-dd').txt"
        $SaveDialog.InitialDirectory = [Environment]::GetFolderPath("Desktop")

        if ($SaveDialog.ShowDialog()) {
            # Build detailed report
            $Content = "==============================================================================`npcHealth | Windows Product Key Report`n==============================================================================`n`nSYSTEM INFORMATION:`n-------------------`nWindows Version:     $($WinVersion.Name)`nBuild Number:        $($WinVersion.Build)`nProduct ID:          $($WinVersion.ProductID)`n`nPRODUCT KEY:`n------------`nKey:                 $($ProductKey -or 'Not found')`nSource:              $KeySource`n`nEXTRACTION METHODS:`n-------------------"

            # Add method results table
            foreach ($method in $MethodResults) {
                $Content += "`n$($method.Icon) $($method.Name)`n   Status: $($method.Status)`n   Result: $($method.Result)`n"
            }

            # Add warnings if applicable
            if ($IsGenericKey) {
                $Content += "`n`nWARNING: GENERIC/PLACEHOLDER KEY DETECTED!`n------------------------------------------------`nThis is a $GenericKeyType generic key.`nThis key WILL NOT WORK for re-activation!`n`nPOSSIBLE EXPLANATION (Not 100% certain):`nYour system may have been activated using unauthorized methods (e.g., AutoKMS,`nMassGravel scripts, or similar tools). These methods force Windows to accept`nnon-genuine keys. We cannot be certain, but this is a common scenario.`n`nLEGITIMATE OPTIONS:`n`n1. Find your original product key from:`n   - Sticker on your PC/laptop case`n   - Email receipt from purchase`n   - UEFI/BIOS firmware`n   - Microsoft account (digital license)`n`n2. Purchase a legitimate Windows 11 Pro RETAIL key:`n   - Search on key indexers like AllKeyShop`n   - Look for 'Windows 11 Pro Retail' keys`n   - AVOID OEM keys - they're for system builders only and won't work after setup`n   - Retail keys can be transferred between computers`n"
            }

            # Add footer
            $Content += "`n`n==============================================================================`nGenerated:           $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')`nTool:                pcHealth Key Grabber`n=============================================================================="

            $Content | Out-File -FilePath $SaveDialog.FileName -Encoding UTF8
            [System.Windows.MessageBox]::Show("Report saved to:`n$($SaveDialog.FileName)", "pcHealth | Saved", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information)
        }
    }
})

# Close Button - Exits the application
$btnClose.Add_Click({
    $Window.Close()
})

# Show window
Write-Host "Opening GUI...`n" -ForegroundColor Green
$Window.ShowDialog() | Out-Null