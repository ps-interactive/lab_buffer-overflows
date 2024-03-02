<#
  .Description
  Windows LabSetup used to provision environment with debugger and service
#>
class LabSetup
{
  # Class properties
  static [String]$Title="Exploit development lab: Buffer Overflows";
  static [String]$Flag="c:\windows\temp\.setup-complete";
  [System.Net.WebClient]$WebClient=$null;
  [String]$ProxyServer="";
  [String]$ProxyUser="";
  [String]$ProxyPassword="";
  [Boolean]$Verbose=$true;
  [Boolean]$Raise=$true;
  # Default class constructor
  LabSetup($settings){
    $this.WebClient = $null;
    $this.ProxyServer = "";
    $this.ProxyUser = "";
    $this.ProxyPassword = "";
    $this.Verbose = $true;
    $this.Raise = $true;
    $this.LoadSettings($settings);
  }
  # Static factory method
  static [LabSetup]Factory($settings){
    return [LabSetup]::New($settings);
  }
  # Method to dynamically set class attributes
  [LabSetup]LoadSettings($settings){
    $settings.keys|%{
      $this."$_" = $settings."$_";
    }
    return $this;
  }
  # Method to display informational messages
  [LabSetup]Info([String]$message){
    echo "Info ($([DateTime]::Now)): $message";
    return $this;
  }
  # Method to display or throw errors
  [LabSetup]Error([system.exception]$error){
    echo "Error ($([DateTime]::Now)): $($error.message)";
    if ($this.Raise){
      throw $error;
    }
    return $this;
  }
  # Method to display verbose messages for debugging
  [LabSetup]Debug([String]$message){
    if ($this.Verbose){
      echo "Debug ($([DateTime]::Now)): $message";
    }
    return $this;
  }
  # Method to instantiate the web client
  [LabSetup]SetWebClient(){
    try {
      $this.WebClient = [System.Net.WebClient]::New();
      if ($this.ProxyServer) {
        return $this.SetProxyServer();
      }
    } catch {
      $this.Error($_);
    }
    return $this;
  }
  # Method to enable HTTP proxy settings for the web client
  [LabSetup]SetProxyServer(){
    if (!$this.ProxyServer){
      return $this;
    }
    try {
      $this.WebClient.Proxy = [System.Net.WebProxy]::New();
      $this.WebClient.Proxy.Address = $this.ProxyServer;
      if (!($this.ProxyUser -and $this.ProxyPassword)){
        return $this;
      }
      $this.WebClient.Proxy.Credentials = [System.Net.NetworkCredential]::New(
        $this.ProxyUser,
        [Runtime.InteropServices.Marshal]::PtrToStringAuto(
          [Runtime.InteropServices.Marshal]::SecureStringToBSTR(
            $this.ProxyPassword
          )
        ),
        ""
      );
    } catch {
      $this.Error($_);
    }
    return $this;
  }
  # Method to check if a file path exists
  [Boolean]Exists([String]$path){
    return test-path -pathtype leaf $path;
  }
  # Method to create a symbolic link
  [LabSetup]Link([String]$source, [String]$destination){
    try {
      if (!$this.Exists($source)){
        $this.Info("Missing source: $source");
        return $this;
      }
      if ($this.Exists($destination)){
        $this.Info("Link exists: $destination");
        return $this;
      }
      New-item -Path $destination -Type symboliclink -Value $source;
    } catch {
      $this.Error($_);
    }
    return $this;
  }
  # Method to create a shortcut
  [LabSetup]Shortcut([String]$source, [String]$link, [String]$arguments){
    try {
      if (!$this.Exists($source)){
        $this.Info("Missing source: $source");
        return $this;
      }
      if ($this.Exists($link)){
        $this.Info("Shortcut exists: $link");
        return $this;
      }
      $shortcut = (New-Object -COMObject WScript.Shell).CreateShortcut($link);
      $shortcut.TargetPath = $source;
      if ($arguments){
        $shortcut.Arguments = $arguments;
      }
      $shortcut.Save();
    } catch {
      $this.Error($_);
    }
    return $this;
  }
  # Method to download file from the web
  [LabSetup]DownloadFile([String]$url, [String]$destination){
    try {
      if ($this.Exists($destination)){
        $this.Info("File Exists: $destination");
        return $this;
      }
      $this.WebClient.DownloadFile($url, $destination);
    } catch {
      $this.Error($_);
    }
    return $this;
  }
  # Method to download web content as a String
  [String]DownloadString([String]$url){
    try {
      return $this.WebClient.DownloadString($url);
    } catch {
      $this.Error($_);
    }
    return "";
  }
  # Main method to begin lab setup
  [LabSetup]Setup(){
    try {
      $this.Info("Running setup: $([LabSetup]::Title)");
      $url = "https://github.com/ps-interactive/lab_buffer-overflows/raw/master/setup";
      $desktop = [System.Environment]::GetfolderPath("CommonDesktopDirectory");
      $sys = [System.Environment]::SystemDirectory;

      if ($this.Exists([LabSetup]::Flag)){
        return $this.Info("Lab already setup, exiting");
      }
      $this.Debug("Setting up environment");
      $this.SetWebClient();

      if (!$this.Exists("$sys\win-server.exe")){
        $this.Info("Downloading vulnerable server");
        $this.DownloadFile("$url/win-server.exe", "$sys\win-server.exe");
        $this.Shortcut(
          "$sys\win-server.exe",
          "$desktop\win-server.lnk",
          $null
        );
      }
      if (!$this.Exists("$sys/cdb.exe")){
        $this.Info("Downloading debugger");
        $this.DownloadFile("$url/cdb.exe", "$sys\cdb.exe");
        $this.Shortcut(
          "$sys\cdb.exe",
          "$desktop\cdb.lnk",
          $null
        );
      }
      if (!$this.Exists("$desktop\debug.lnk")){
        $this.Info("Creating debugger shortcut");
        $this.Shortcut(
          "$sys\cdb.exe",
          "$desktop\debugger.lnk",
          '-pn win-server.exe -pd -c "g"'
        );
      }
      $this.Info("Setting up firewall rules");
      foreach ($port in @(65534, 65534, 4444, 80, 443)){
        foreach ($direction in @("in", "out")){
          netsh advfirewall firewall add rule name="tcp $port" dir=$direction `
            action=allow protocol=tcp localport=$port
        }
      }
      "$([DateTime]::Now)"|out-file -encoding ascii -filepath [LabSetup]::flag;
      $this.Info("Setup complete");
    } catch {
      $this.Error($_);
    }
    return $this;
  }
};
## Instantiate instance and begin setup:
#$client = [LabSetup]::Factory(@{
#  ProxyServer="http://192.168.243.133:8080";
#  ProxyUser="ProxyUser";
#  ProxyPassword="ProxyPassword";
#  Verbose=$true;
#  Raise=$true;
#});
#$client.Setup();