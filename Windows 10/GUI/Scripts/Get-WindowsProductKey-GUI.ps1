# ============================================================================
# PowerShell Windows Product Key Grabber - pcHealthPlus-VS (GUI Version)
# ============================================================================
#
# This is the GUI version using WPF - designed for pcHealthPlus-VS project.
# For the command-line version, see the pcHealthPlus repository.
#
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
function Get-SystemTheme {
    $theme = Get-ItemPropertyValue -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize" `
        -Name AppsUseLightTheme -ErrorAction SilentlyContinue
    ($null -eq $theme -or $theme -eq 1) ? "Light" : "Dark"
}

# ============================================================================
# FUNCTION: Get-ProductKeyFromDigitalProductId
# ============================================================================
function Get-ProductKeyFromDigitalProductId {
    try {
        $DigitalProductId = Get-ItemPropertyValue -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion" `
            -Name DigitalProductId -ErrorAction Stop

        if (-not $DigitalProductId) {
            return $null
        }

        # Extract the key portion (bytes 52-66 = 15 bytes)
        $key = $DigitalProductId[52..66]
        $chars = "BCDFGHJKMPQRTVWXY2346789"
        $productKey = ""

        # Check for Windows 8+ key (has special N-character encoding)
        $isWin8Plus = ($key[14] -shr 3) -band 1
        $key[14] = ($key[14] -band 0xF7) -bor (($isWin8Plus -band 2) -shl 2)

        # Decode the key using Base24
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
            $nIndex = $chars.IndexOf($productKey[0])
            $productKey = $productKey.Substring(1).Insert($nIndex, "N")
        }

        # Format with dashes using regex
        $formattedKey = $productKey -replace '(.{5})(?=.)', '$1-'
        return $formattedKey
    } catch {
        return $null
    }
}

# ============================================================================
# FUNCTION: Get-ProductKeyFromOA3
# ============================================================================
function Get-ProductKeyFromOA3 {
    try {
        $key = (Get-CimInstance -ClassName SoftwareLicensingService -ErrorAction Stop).OA3xOriginalProductKey
        if ($key) {
            return $key
        }
    } catch {
        # Silently fail
    }
    return $null
}

# ============================================================================
# FUNCTION: Get-WindowsVersion
# ============================================================================
function Get-WindowsVersion {
    try {
        $OS = Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction Stop
        $ProductID = Get-ItemPropertyValue "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion" -Name ProductID

        @{
            Name = $OS.Caption
            Build = $OS.BuildNumber
            ProductID = $ProductID
        }
    }
    catch {
        @{ Name = "Unknown Windows Version"; Build = "Unknown"; ProductID = "Unknown" }
    }
}

# ============================================================================
# FUNCTION: Test-ProductKeyFormat
# ============================================================================
function Test-ProductKeyFormat {
    param([string]$Key)
    -not [string]::IsNullOrEmpty($Key) -and $Key -match '^[A-Z0-9]{5}-[A-Z0-9]{5}-[A-Z0-9]{5}-[A-Z0-9]{5}-[A-Z0-9]{5}$'
}

# ============================================================================
# FUNCTION: Invoke-AllKeyMethod
# ============================================================================
function Invoke-AllKeyMethod {
    $methods = @()

    # METHOD 1: OA3 (UEFI/BIOS) - Plaintext readout
    $oa3Key = Get-ProductKeyFromOA3
    $methods += if ($oa3Key -and (Test-ProductKeyFormat $oa3Key)) {
        @{ Name = "OA3 (UEFI/BIOS) - Plaintext"; Status = "Success"; Result = $oa3Key }
    } else {
        @{ Name = "OA3 (UEFI/BIOS) - Plaintext"; Status = "Failed"; Result = "N/A" }
    }

    # METHOD 2: DigitalProductId (Registry) - Decoded
    $regKey = Get-ProductKeyFromDigitalProductId
    $methods += if ($regKey -and (Test-ProductKeyFormat $regKey)) {
        @{ Name = "DigitalProductId (Registry) - Decoded"; Status = "Success"; Result = $regKey }
    } else {
        @{ Name = "DigitalProductId (Registry) - Decoded"; Status = "Failed"; Result = "N/A" }
    }

    # Select best key (prefer Registry over OA3)
    $bestKey = $regKey ?? $oa3Key
    $bestSource = if ($regKey) { "Registry (DigitalProductId)" } elseif ($oa3Key) { "UEFI/BIOS Firmware (OA3)" } else { "None" }

    @{ BestKey = $bestKey; Source = $bestSource; Methods = $methods }
}

# ============================================================================
# MAIN EXECUTION
# ============================================================================

# Get Windows version and attempt all key extraction methods
$WinVersion = Get-WindowsVersion
$results = Invoke-AllKeyMethod
$ProductKey, $KeySource, $MethodResults = $results.BestKey, $results.Source, $results.Methods

# Check if key is generic
$IsGenericKey = $ProductKey -and $GenericKeys.ContainsKey($ProductKey)
$GenericKeyType = if ($IsGenericKey) { $GenericKeys[$ProductKey] } else { "" }

# Detect system theme for UI colors
$Theme = Get-SystemTheme

# Define UI colors based on theme
$colors = if ($Theme -eq "Dark") {
    @{
        BgColor = "#1E1E1E"; FgColor = "#FFFFFF"; BorderColor = "#3F3F46"; HeaderBg = "#2D2D30"
        SuccessBg = "#0D3B26"; SuccessFg = "#4ADE80"; ErrorBg = "#3B0D0D"; ErrorFg = "#F87171"
        WarningBg = "#3B2D0D"; WarningFg = "#FACC15"
    }
} else {
    @{
        BgColor = "#FFFFFF"; FgColor = "#1A1A1A"; BorderColor = "#D4D4D8"; HeaderBg = "#F5F5F5"
        SuccessBg = "#D1FAE5"; SuccessFg = "#065F46"; ErrorBg = "#FEE2E2"; ErrorFg = "#991B1B"
        WarningBg = "#FEF3C7"; WarningFg = "#92400E"
    }
}

# ============================================================================
# GUI CONSTRUCTION (WPF XAML)
# ============================================================================

[xml]$xaml = @"
<Window
    xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
    xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
    Title="pcHealthPlus-VS | Windows Key Grabber"
    Width="820" Height="850"
    MinWidth="600" MinHeight="500"
    WindowStartupLocation="CenterScreen"
    Background="$($colors.BgColor)"
    ResizeMode="CanResize">

    <DockPanel Margin="20">
        <!-- Action Buttons (docked to bottom, always visible) -->
        <Grid DockPanel.Dock="Bottom" Margin="0,15,0,0">
            <Grid.ColumnDefinitions>
                <ColumnDefinition Width="*"/>
                <ColumnDefinition Width="*"/>
            </Grid.ColumnDefinitions>

            <Button Grid.Column="0" Name="btnSave" Content="Save Report"
                    Padding="12,8" FontSize="12" Margin="0,0,5,0"
                    Background="$($colors.HeaderBg)" Foreground="$($colors.FgColor)" BorderBrush="$($colors.BorderColor)"/>
            <Button Grid.Column="1" Name="btnClose" Content="Close"
                    Padding="12,8" FontSize="12" Margin="5,0,0,0"
                    Background="$($colors.HeaderBg)" Foreground="$($colors.FgColor)" BorderBrush="$($colors.BorderColor)"/>
        </Grid>

        <!-- Scrollable content area -->
        <ScrollViewer VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Disabled">
            <StackPanel>

                <!-- Header -->
                <Border Background="$($colors.HeaderBg)" Padding="15" CornerRadius="6" Margin="0,0,0,15">
                    <StackPanel>
                        <TextBlock Text="Windows Product Key Grabber"
                                   FontSize="20" FontWeight="Bold" Foreground="$($colors.FgColor)"/>
                        <TextBlock Text="pcHealthPlus-VS"
                                   FontSize="11" Foreground="$($colors.FgColor)" Opacity="0.7" Margin="0,5,0,0"/>
                    </StackPanel>
                </Border>

                <!-- System Info -->
                <Border BorderBrush="$($colors.BorderColor)" BorderThickness="1"
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

                        <TextBlock Grid.Row="0" Grid.Column="0" Text="Windows Version:"
                                   Foreground="$($colors.FgColor)" Opacity="0.7" FontSize="11"/>
                        <TextBlock Grid.Row="0" Grid.Column="1" Name="txtWinVersion"
                                   Foreground="$($colors.FgColor)" FontSize="11" FontWeight="Medium"/>

                        <TextBlock Grid.Row="1" Grid.Column="0" Text="Product ID:"
                                   Foreground="$($colors.FgColor)" Opacity="0.7" FontSize="11" Margin="0,5,0,0"/>
                        <TextBlock Grid.Row="1" Grid.Column="1" Name="txtProductID"
                                   Foreground="$($colors.FgColor)" FontSize="11" FontWeight="Medium" Margin="0,5,0,0"/>

                        <TextBlock Grid.Row="2" Grid.Column="0" Text="Key Source:"
                                   Foreground="$($colors.FgColor)" Opacity="0.7" FontSize="11" Margin="0,5,0,0"/>
                        <TextBlock Grid.Row="2" Grid.Column="1" Name="txtKeySource"
                                   Foreground="$($colors.FgColor)" FontSize="11" FontWeight="Medium" Margin="0,5,0,0"/>
                    </Grid>
                </Border>

                <!-- Product Key Display -->
                <Border BorderBrush="$($colors.BorderColor)" BorderThickness="2"
                        Padding="20" CornerRadius="8" Margin="0,0,0,15" Background="$($colors.HeaderBg)">
                    <StackPanel>
                        <TextBlock Text="Primary Product Key"
                                   FontSize="12" FontWeight="SemiBold" Foreground="$($colors.FgColor)" Opacity="0.7"/>
                        <TextBlock Name="txtProductKey"
                                   FontSize="22" FontFamily="Consolas" FontWeight="Bold"
                                   Foreground="$($colors.FgColor)" Margin="0,8,0,0" TextAlignment="Center"/>
                    </StackPanel>
                </Border>

                <!-- Extraction Methods Section Header -->
                <TextBlock Text="All Extraction Methods &amp; Keys Found"
                           FontSize="14" FontWeight="SemiBold" Foreground="$($colors.FgColor)" Margin="0,5,0,10"/>

                <!-- Extraction Methods Table -->
                <Border BorderBrush="$($colors.BorderColor)" BorderThickness="1"
                        CornerRadius="6" Margin="0,0,0,15">
                    <Grid Margin="12">
                        <Grid.RowDefinitions>
                            <RowDefinition Height="Auto"/>
                            <RowDefinition Height="Auto"/>
                            <RowDefinition Height="Auto"/>
                        </Grid.RowDefinitions>

                        <Grid Grid.Row="0" Margin="0,0,0,10">
                            <Grid.ColumnDefinitions>
                                <ColumnDefinition Width="240"/>
                                <ColumnDefinition Width="90"/>
                                <ColumnDefinition Width="*"/>
                                <ColumnDefinition Width="80"/>
                            </Grid.ColumnDefinitions>
                            <TextBlock Grid.Column="0" Text="METHOD" FontSize="10" FontWeight="Bold"
                                       Foreground="$($colors.FgColor)" Opacity="0.5"/>
                            <TextBlock Grid.Column="1" Text="STATUS" FontSize="10" FontWeight="Bold"
                                       Foreground="$($colors.FgColor)" Opacity="0.5"/>
                            <TextBlock Grid.Column="2" Text="PRODUCT KEY" FontSize="10" FontWeight="Bold"
                                       Foreground="$($colors.FgColor)" Opacity="0.5"/>
                            <TextBlock Grid.Column="3" Text="ACTION" FontSize="10" FontWeight="Bold"
                                       Foreground="$($colors.FgColor)" Opacity="0.5"/>
                        </Grid>

                        <Border Grid.Row="1" Name="row1" Padding="0,8"/>
                        <Border Grid.Row="2" Name="row2" Padding="0,8"/>
                    </Grid>
                </Border>

                <!-- Status Message Box -->
                <Border Name="msgBox" BorderThickness="1"
                        Padding="15" CornerRadius="6" Margin="0,0,0,0">
                    <StackPanel>
                        <TextBlock Name="msgTitle" FontSize="13" FontWeight="SemiBold" Margin="0,0,0,8"/>
                        <TextBlock Name="msgBody" FontSize="11" TextWrapping="Wrap" LineHeight="18"/>
                    </StackPanel>
                </Border>

            </StackPanel>
        </ScrollViewer>
    </DockPanel>
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
foreach ($i in 0..([Math]::Min($MethodResults.Count, 2) - 1)) {
    $method = $MethodResults[$i]
    $row = @($row1, $row2)[$i]

    $grid = [System.Windows.Controls.Grid]::new()
    240, 90, "*", 80 | ForEach-Object {
        $grid.ColumnDefinitions.Add([System.Windows.Controls.ColumnDefinition]@{Width=$_})
    }

    # Add method name
    $tb = [System.Windows.Controls.TextBlock]@{
        Text = $method.Name
        FontSize = 12
        Foreground = $colors.FgColor
    }
    [System.Windows.Controls.Grid]::SetColumn($tb, 0)
    $grid.Children.Add($tb) | Out-Null

    # Add status
    $statusColor = switch ($method.Status) {
        "Success" { $colors.SuccessFg }
        "Partial" { $colors.WarningFg }
        default { $colors.ErrorFg }
    }
    $tb = [System.Windows.Controls.TextBlock]@{
        Text = $method.Status
        FontSize = 12
        FontWeight = "SemiBold"
        Foreground = $statusColor
    }
    [System.Windows.Controls.Grid]::SetColumn($tb, 1)
    $grid.Children.Add($tb) | Out-Null

    # Add product key
    $tb = [System.Windows.Controls.TextBlock]@{
        Text = $method.Result
        FontSize = 12
        FontFamily = "Consolas"
        FontWeight = "Medium"
        Foreground = $colors.FgColor
        Opacity = 0.9
    }
    [System.Windows.Controls.Grid]::SetColumn($tb, 2)
    $grid.Children.Add($tb) | Out-Null

    # Add copy button only if key was found successfully
    if ($method.Status -eq "Success" -and $method.Result -ne "N/A") {
        $btn = [System.Windows.Controls.Button]@{
            Content = "Copy"
            FontSize = 10
            Padding = "8,4"
            Background = $colors.HeaderBg
            Foreground = $colors.FgColor
            BorderBrush = $colors.BorderColor
            Cursor = "Hand"
        }
        $keyToCopy = $method.Result
        $btn.Add_Click({
            Set-Clipboard -Value $keyToCopy
            [System.Windows.MessageBox]::Show("Key copied to clipboard!`n$keyToCopy", "pcHealthPlus-VS | Copied", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information)
        }.GetNewClosure())
        [System.Windows.Controls.Grid]::SetColumn($btn, 3)
        $grid.Children.Add($btn) | Out-Null
    }

    $row.Child = $grid
}

# ============================================================================
# Display Status Message
# ============================================================================
$msgBox.Visibility = "Visible"
$multipleKeysFound = ($MethodResults | Where-Object Status -eq "Success").Count -gt 1

$msgConfig = if (-not $ProductKey) {
    @{
        Background = $colors.ErrorBg
        Foreground = $colors.ErrorFg
        Title = "No Product Key Found"
        Body = "No product key could be found in registry or UEFI firmware.`n`nThis may indicate:`n- Digital license (linked to Microsoft account)`n- Volume license (KMS/MAK activation)`n- Corrupted registry data"
    }
} elseif ($IsGenericKey) {
    @{
        Background = $colors.WarningBg
        Foreground = $colors.WarningFg
        Title = "WARNING: Generic/Placeholder Key Detected"
        Body = "This is a generic $GenericKeyType key used by OEMs and system integrators for pre-installation.`n`nThis key WILL NOT WORK for re-activation after a clean install!`n`nPOSSIBLE EXPLANATION (Not 100% certain):`nYour system may have been activated using unauthorized methods (e.g., AutoKMS, MassGravel scripts, or similar tools). These methods force Windows to accept non-genuine keys. We cannot be certain, but this is a common scenario.`n`nLEGITIMATE OPTIONS:`n`n1. Find your original product key:`n   - Sticker on your PC/laptop case`n   - Email receipt from purchase`n   - Digital license (linked to Microsoft account)`n`n2. Purchase a legitimate Windows 11 Pro RETAIL key:`n   - Search on key indexers like AllKeyShop`n   - Look for 'Windows 11 Pro Retail' keys`n   - AVOID OEM keys - they're for system builders only and won't work after Windows setup`n   - Retail keys can be transferred between computers"
    }
} elseif ($multipleKeysFound) {
    @{
        Background = $colors.SuccessBg
        Foreground = $colors.SuccessFg
        Title = "Multiple Keys Found - Likely Upgraded System"
        Body = "Multiple product keys were detected, which typically indicates this system has been upgraded or re-activated with a different key.`n`nRECOMMENDATION: Use the DigitalProductId (Registry) key, as it represents the CURRENT key Windows is actively using. The OA3 key is the original manufacturer key that came with the device.`n`nNOTE: The Registry key is calculated using reverse-engineered algorithms and may be incorrect in some edge cases. Always verify the key works before relying on it."
    }
} else {
    @{
        Background = $colors.SuccessBg
        Foreground = $colors.SuccessFg
        Title = "Valid Product Key"
        Body = "This key appears to be valid and can be used for Windows re-activation. Save it in a secure location for future use."
    }
}

$msgBox.Background = $msgConfig.Background
$msgTitle.Foreground = $msgBody.Foreground = $msgConfig.Foreground
$msgTitle.Text = $msgConfig.Title
$msgBody.Text = $msgConfig.Body

# ============================================================================
# Button Event Handlers
# ============================================================================

# Save Button - Saves complete report to text file
$btnSave.Add_Click({
    if ($ProductKey -or $MethodResults.Count -gt 0) {
        $SaveDialog = New-Object Microsoft.Win32.SaveFileDialog
        $SaveDialog.Filter = "Text files (*.txt)|*.txt|All files (*.*)|*.*"
        $SaveDialog.FileName = "Windows-Key-Report-$(Get-Date -Format 'yyyy-MM-dd').txt"
        $SaveDialog.InitialDirectory = [Environment]::GetFolderPath("Desktop")

        if ($SaveDialog.ShowDialog()) {
            # Build detailed report
            $Content = "==============================================================================`npcHealthPlus-VS | Windows Product Key Report`n==============================================================================`n`nSYSTEM INFORMATION:`n-------------------`nWindows Version:     $($WinVersion.Name)`nBuild Number:        $($WinVersion.Build)`nProduct ID:          $($WinVersion.ProductID)`n`nPRODUCT KEY:`n------------`nKey:                 $($ProductKey -or 'Not found')`nSource:              $KeySource`n`nEXTRACTION METHODS:`n-------------------"

            # Add method results table
            foreach ($method in $MethodResults) {
                $Content += "`n$($method.Icon) $($method.Name)`n   Status: $($method.Status)`n   Result: $($method.Result)`n"
            }

            # Add warnings if applicable
            if ($IsGenericKey) {
                $Content += "`n`nWARNING: GENERIC/PLACEHOLDER KEY DETECTED!`n------------------------------------------------`nThis is a $GenericKeyType generic key.`nThis key WILL NOT WORK for re-activation!`n`nPOSSIBLE EXPLANATION (Not 100% certain):`nYour system may have been activated using unauthorized methods (e.g., AutoKMS,`nMassGravel scripts, or similar tools). These methods force Windows to accept`nnon-genuine keys. We cannot be certain, but this is a common scenario.`n`nLEGITIMATE OPTIONS:`n`n1. Find your original product key from:`n   - Sticker on your PC/laptop case`n   - Email receipt from purchase`n   - UEFI/BIOS firmware`n   - Microsoft account (digital license)`n`n2. Purchase a legitimate Windows 11 Pro RETAIL key:`n   - Search on key indexers like AllKeyShop`n   - Look for 'Windows 11 Pro Retail' keys`n   - AVOID OEM keys - they're for system builders only and won't work after setup`n   - Retail keys can be transferred between computers`n"
            }

            # Add footer
            $Content += "`n`n==============================================================================`nGenerated:           $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')`nTool:                pcHealthPlus-VS Key Grabber`n=============================================================================="

            $Content | Out-File -FilePath $SaveDialog.FileName -Encoding UTF8
            [System.Windows.MessageBox]::Show("Report saved to:`n$($SaveDialog.FileName)", "pcHealthPlus-VS | Saved", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information)
        }
    }
})

# Close Button - Exits the application
$btnClose.Add_Click({
    $Window.Close()
})

# Show window
$Window.ShowDialog() | Out-Null
