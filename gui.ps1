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