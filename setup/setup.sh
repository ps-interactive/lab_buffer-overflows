#!/bin/bash
# Linux LabSetup used to provision environment with debugger and service
function LabSetup() {
  # LabSetup properties
  local _Title="Exploit Development Lab: Buffer Overflows";
  local _Flag="/tmp/.setup-complete";
  local _Verbose="true";
  local _Proxy="$1";
  local _Now="";
  local -a _Apps=(
    "gcc"
    "gcc-multilib"
    "mingw-w64"
    "git"
    "net-tools"
    "zip"
    "gzip"
    "python3"
    "nasm"
    "gdb"
    "net-tools"
    "python3-pip"
  );
  # Method to check if a file path exists
  Exists() {
    test -f $1 || return 1;
    return 0;
  }  
  # Method to display informational messages
  Info() {
    [[ -z "$1" ]] || echo "INFO ($(date)): ${@}";
    return 0;
  }
  # Method to display verbose messages for debugging
  Debug() {
    if [[ "${_Verbose}" ]]; then
      [[ -z "$1" ]] || echo "DEBUG ($(date)): ${@}";
    fi;
    return 0;
  }
  # Method to display error messages
  Error() {
    [[ -z "$1" ]] || echo "ERROR ($(date)): ${@}";
    return 1;
  }
  # Method to install packages and dependencies
  Install() {
    Info "Setting up APT repository";
    Info "Updating repository and installing dependencies";
    http_proxy=${_Proxy} apt update;
    http_proxy=${_Proxy} apt update;
    http_proxy=${_Proxy} DEBIAN_FRONTEND=noninteractive apt -y --force-yes install ${_Apps[@]};

    Info "Setting up GDB peda extension";
    git -c http.proxy=${_Proxy} clone https://github.com/longld/peda.git ~/peda
    echo "source ~/peda/peda.py" >> ~/.gdbinit

    Info "Setting up boofuzz and ROPgadget packages"
    python3 -m pip --proxy ${_Proxy} install boofuzz ROPgadget;
    return 0;
  }
  # Method to download a file from the web
  DownloadFile(){
    curl --proxy ${_Proxy} -o "$2" -skL "$1";
    return 0;
  }
  # Method to download the lab files from the Github repository
  DownloadFiles() {
    Info "Downloading files";
    local _url="https://github.com/ps-interactive/lab_buffer-overflows/raw/master";
    local _server="${_url}/setup/lin-server";
    local _url="${_url}/exploitation";
    local -a _files=(
      "exploit-generator.sh"
      "fuzz-server.py"
      "linux-exploit.py"
      "windows-exploit.py"
      "encode-command.py"
      "reverse-tcp.ps1"
      "x86-exec-cradle.asm"
      "x86-reverse-tcp.asm"
    );

    test -d /opt/lab || mkdir -p /opt/lab;
    DownloadFile "${_server}" "/opt/lab/lin-server";
    for _file in ${_files[@]}; do
      DownloadFile "${_url}/${_file}" "/opt/lab/${_file}";
      chmod +x "/opt/lab/${_file}";
    done;
    return 0;
  }
  # Method to create the lab service
  InstallService() {
    Info "Setting up vulnerable service";
    if ! (Exists "/opt/lab/lin-server"); then
      Error "Missing file";
      return 1;
    fi;
    cat << EOF > /etc/systemd/system/lin-server.service
  [Unit]
  Description=Vulnerable Linux Server
  After=network.target auditd.service sshd.service

  [Service]
  ExecStart=/opt/lab/lin-server
  ExecReload=/opt/lab/lin-server
  KillMode=process
  Restart=always
  RestartSec=3
  [Install]
  WantedBy=multi-user.target
  Alias=vuln.service
EOF
    systemctl enable lin-server
    systemctl daemon-reload
    systemctl start lin-server
    return 0;
  }
  # Method to setup the learner environment
  SetupLearner() {
    Info "Setting up learner environment";
    chmod +x /opt/lab/*
    for _file in /opt/lab/*.py; do
      ln -s "${_file}" /usr/bin/$(basename "${_file}");
    done;
    for _file in /opt/lab/*.ps1; do
      ln -s "${_file}" /tmp/$(basename "${_file}");
    done;
    for _file in /opt/lab/*.sh; do
      ln -s "${_file}" /tmp/$(basename "${_file}");
    done;
    return 0;
  }
  # Main method to setup the lab environment
  Setup() {
    Info "${_Title}";
    if (Exists "${_Flag}"); then
      Error "Environment already setup";
      return 1;
    fi;
    Info "Setting up environment";
    Install || (Error "Failed install"; return 1);
    DownloadFiles || (Error "Failed downloads"; return 1);
    InstallService || (Error "Failed service install"; return 1);
    SetupLearner || (Error "Failed learner setup"; return 1);
    Info "Setup complete";
    touch "${_Flag}";
    return 0
  }
  Setup;
}

LabSetup "$1" &>/tmp/setup.log;
cat /tmp/setup.log;
rm /tmp/setup.log;