using module Microsoft.PowerShell.Management
using module Microsoft.PowerShell.Utility

using namespace System.Management.Automation
using namespace System.PresentationFramework
using namespace System.Windows.Markup

$ErrorActionPreferenceBackup = $ErrorActionPreference
$ErrorActionPreference = [ActionPreference]::Stop

Set-StrictMode -Version 'Latest'

Add-Type -AssemblyName 'PresentationFramework'

function Get-EuroExchange {
    [CmdletBinding(DefaultParameterSetName = 'Calculate')]
    param (
        [Parameter(ParameterSetName = "Calculate", Mandatory = $true, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [ValidateSet('AUD', 'BGN', 'BRL', 'CAD', 'CHF', 'CNY', 'CZK', 'DKK', 'GBP', 'HKD', 'HRK', 'HUF', 'IDR', 'ILS', 'INR', 'ISK', 'JPY', 'KRW', 'MXN', 'MYR', 'NOK', 'NZD', 'PHP', 'PLN', 'RON', 'RUB', 'SEK', 'SGD', 'THB', 'TRY', 'USD', 'ZAR')]
        [Alias("Währung")]
        [string]$Currency,

        [Parameter(ParameterSetName = "Calculate", ValueFromPipelineByPropertyName = $true)]
        [ValidateRange(0.0001, 2147483647)]
        [Alias("Euronen")]
        [decimal]$Euros = 1,

        [Parameter(ParameterSetName = "Overview", Mandatory=$true)]
        [switch]$ListCurrency
    )
    begin {
        [datetime]$StartTime = Get-Date

        #region Update local cache and read it

        # ! Build Cachefile:
        [string]$EuroExchangeCacheFile = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath 'EcbEuroExchangeCache.xml'

        # ! Exist Cachefile read timestamp:
        [timespan]$ECBCacheDifferenceSpan = New-TimeSpan -Hours 999
        if ((Test-Path -Path $EuroExchangeCacheFile)) {
            'ECB-EuroExchange-Cache-File found!' | Write-Verbose
            [xml]$EuroExchangeContent = Get-Content -Path $EuroExchangeCacheFile
            [datetime]$EuroExchangeTime = $EuroExchangeContent.Envelope.Cube.Cube | Select-Object -ExpandProperty 'time'
            [timespan]$ECBCacheDifferenceSpan = (Get-Date) - $EuroExchangeTime
        }

        # ! Is Cache-Difference-TimeSpan greater 39h than update from ECB:
        if($ECBCacheDifferenceSpan.TotalHours -ge 39) {
            'The ECB-EuroExchange-Cache-File is updated because the file was not found or is older than 39 hours.' | Write-Verbose
            Invoke-WebRequest -Uri "http://www.ecb.europa.eu/stats/eurofxref/eurofxref-daily.xml" | Select-Object -ExpandProperty Content | Set-Content -Path $EuroExchangeCacheFile -Force
        }

        # ! Read Cachefile for the next stapes:
        [xml]$EuroExchangeContent = Get-Content -Path $EuroExchangeCacheFile
        $EuroExchangeCubes = $EuroExchangeContent.Envelope.Cube.Cube.Cube
        "ECB-EuroExchange-Cache-File from $($EuroExchangeContent.Envelope.Cube.Cube | Select-Object -ExpandProperty 'time') read it." | Write-Verbose

        #endregion

        switch ($PSCmdlet.ParameterSetName) {
            'Overview' {
                'Get-EuroExchange works in Overview-Mode.' | Write-Verbose
                $EuroExchangeCubes | ForEach-Object -Process { [PSCustomObject]@{ Currency = $_.currency } } | Sort-Object -Property 'Currency'
            }
            'Calculate' {
                'Get-EuroExchange works in Calculate-Mode.' | Write-Verbose
            }
        }
    }
    process {
        if($PSCmdlet.ParameterSetName -eq 'Calculate') {
            [decimal]$CurrencyRate = $EuroExchangeCubes | Where-Object -Property 'currency' -EQ -Value $Currency | Select-Object -ExpandProperty 'rate'
            [PSCustomObject]@{
                Currency    = $Currency.ToUpper()
                Rate        = $CurrencyRate
                Euros       = $Euros
                SumCurrency = $CurrencyRate * $Euros
            }
        }
    }
    end {
        [timespan]$Duration = (Get-Date) - $StartTime
        "Done in $($Duration.TotalMilliseconds) ms!" | Write-Verbose
    }
}

 # Übersicht aller möglichen Wechselkurse
 Get-EuroExchange -ListCurrency

# Umrechnung von 100 EUR in JPY
Get-EuroExchange -Currency 'JPY' -Euros 100

Show-Command -Name 'Get-EuroExchange' -NoCommonParameter -ErrorPopup | Out-GridView -OutputMode Multiple

function EuroRateCalculate([string]$Currency, [double]$Euros) {
    try {
        # Berechnung:
        $Result = Get-EuroExchange -Currency $Currency -Euros $Euros
        [double]$Rate        = $Result.Rate
        [double]$SumCurrency = $Result.SumCurrency
    }
    catch {
        # NaN im Fehlerfall, z.B. ungültiger Euro-Betrag oder das Ergebnis der Multiplikation (Rate * Euro) ist zu groß.
        [double]$Rate        = [double]::NaN
        [double]$SumCurrency = [double]::NaN
    }
    # Ausgabe:
    $Script:My.RateControl.Text  = "{0:#,##0.0000} {1}" -f $Rate       , $Currency
    $Script:My.SummeControl.Text = "{0:#,##0.0000} {1}" -f $SumCurrency, $Currency
}
# Sammel-Objekt als Container für die diversen Unterobjekte die im weiteren Verlauf benötigt werden.
# Ein Synchronized-HashTable ist Thread-Sicher und kann Thread-Übergreifend genutzt werden.
$Script:My = [HashTable]::Synchronized(@{})

# XAML-WPF-Window-Struktur
$Script:My.WindowXaml = @'
<Window
    xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
    xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
    Title="€ CALCULATOR"
    Width="336"
    Height="220"
    FontFamily="Consolas"
    FontSize="14"
    WindowStartupLocation="CenterScreen">
    <Viewbox
        Margin="15"
        Stretch="Uniform"
        StretchDirection="Both">
        <Grid>
            <Grid.ColumnDefinitions>
                <ColumnDefinition />
                <ColumnDefinition />
            </Grid.ColumnDefinitions>
            <Grid.RowDefinitions>
                <RowDefinition Height="AUTO" />
                <RowDefinition MinHeight="10" />
                <RowDefinition MinHeight="40" />
                <RowDefinition MinHeight="40" />
                <RowDefinition MinHeight="40" />
            </Grid.RowDefinitions>
            <ComboBox
                x:Name="WährungenControl"
                Grid.Row="0"
                Grid.Column="0"
                VerticalAlignment="Top"
                HorizontalContentAlignment="Center"
                FontSize="20"
                SelectedValue="USD" />
            <TextBlock
                Grid.Row="0"
                Grid.Column="1"
                Margin="10,0,0,0"
                VerticalAlignment="Center">
                Währungssymbol
            </TextBlock>
            <TextBox
                x:Name="RateControl"
                Grid.Row="2"
                Grid.Column="0"
                VerticalAlignment="Center"
                FontWeight="Bold"
                IsReadOnly="True"
                TextAlignment="Right" />
            <TextBlock
                Grid.Row="2"
                Grid.Column="1"
                Margin="10,0,0,0"
                VerticalAlignment="Center"
                FontWeight="Bold">
                Rate
            </TextBlock>
            <TextBox
                x:Name="EurosControl"
                Grid.Row="3"
                Grid.Column="0"
                VerticalAlignment="Center"
                TextAlignment="Right" />
            <TextBlock
                Grid.Row="3"
                Grid.Column="1"
                Margin="10,0,0,0"
                VerticalAlignment="Center">
                € (EUR)
            </TextBlock>
            <TextBox
                x:Name="SummeControl"
                Grid.Row="4"
                Grid.Column="0"
                MinWidth="195"
                VerticalAlignment="Center"
                FontWeight="Bold"
                IsReadOnly="True"
                TextAlignment="Right" />
            <TextBlock
                Grid.Row="4"
                Grid.Column="1"
                Margin="10,0,0,0"
                VerticalAlignment="Center"
                FontWeight="Bold">
                SUMME = Rate * €
            </TextBlock>
        </Grid>
    </Viewbox>
</Window>
'@

# Das Window-Objekt wird über die XAML-Struktur materialisiert:
$Script:My.Window = [XamlReader]::Parse($Script:My.WindowXaml)

# Aus dem Window-Objekt werden die benötigten Steuerelemente über das Attribute X:Name lokalisiert und referenziert:
$Script:My.WährungenControl = $Script:My.Window.FindName('WährungenControl')
$Script:My.RateControl      = $Script:My.Window.FindName('RateControl')
$Script:My.EurosControl     = $Script:My.Window.FindName('EurosControl')
$Script:My.SummeControl     = $Script:My.Window.FindName('SummeControl')

# Die ComboBox erhält ihre Werte die später vom Benutzer ausgewählt werden können:
Get-EuroExchange -ListCurrency | ForEach-Object -Process { $Script:My.WährungenControl.Items.Add($_.Currency) | Out-Null }

# Die ComboBox stößt die Berechnung der Ausgabe (s.o. EuroRateCalculate) an, wenn die Benutzer-Auswahl (SelectionChanged-Event) wechselt:
$Script:My.WährungenControl.Add_SelectionChanged({ EuroRateCalculate -Currency $Script:My.WährungenControl.SelectedItem -Euros $Script:My.EurosControl.Text })

# Das erste Element der ComboBox wird programmatisch ausgewählt:
$Script:My.WährungenControl.SelectedIndex = 0

# Die TextBox stößt die Berechnung der Ausgabe (s.o. EuroRateCalculate) an, wenn der Euro-Text sich ändert (TextChanged):
$Script:My.EurosControl.Add_TextChanged({ EuroRateCalculate -Currency $Script:My.WährungenControl.SelectedItem -Euros $Script:My.EurosControl.Text })

# In der TextBox wird der Default-Wert auf 1 Euro gesetzt:
$Script:My.EurosControl.Text = '1'

# Das WPF-Window wird obenauf angezeigt:
$Script:My.Window.Topmost = $true
$Script:My.Window.ShowDialog() | Out-Null

# $Script:My.WährungenControl | Get-Member -MemberType 'Event'

Remove-Variable -Name 'My' -Force
Remove-Item -Path 'function:\EuroRateCalculate', 'function:\Get-EuroExchange' -Force
Set-StrictMode -Off
$ErrorActionPreference = $ErrorActionPreferenceBackup
Remove-Module -Name 'Microsoft.PowerShell.Management', 'Microsoft.PowerShell.Utility' -Force

