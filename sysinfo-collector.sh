#!/bin/bash
# System Information Collector
# Modular, interactive or non-interactive with options.
# Can save locally or upload via eos-sendlog.

SCRIPT_VERSION="1.6"
timestamp=$(date +"%Y-%m-%d_%H-%M-%S")
outfile="/tmp/sysreport-$timestamp.txt"

###########################
### HELP ##################
###########################

show_help() {
    echo "System Information Collector v$SCRIPT_VERSION"
    echo
    echo "Usage: $0 [options]"
    echo
    echo "Without options, script runs interactively."
    echo "With options, script runs non-interactively."
    echo
    echo "Information collection options:"
    echo "  -nv,  --nvidia       Collect NVIDIA information"
    echo "  -in,  --intel        Collect Intel GPU information"
    echo "  -bc,  --broadcom     Collect Broadcom WiFi information"
    echo "  -inst,--installer    Collect EndeavourOS installer log"
    echo "  -part,--partitions   Collect partitions and fstab info"
    echo "  -boot,--bootlog      Collect boot log (journalctl -b -0)"
    echo "  -pkg, --packages     Collect installed packages list"
    echo "  -all, --all          Collect everything"
    echo
    echo "Output options:"
    echo "      --local          Save locally only, do not upload"
    echo "      --pastebin       Upload automatically via eos-sendlog"
    echo "      --help           Show this help"
    exit 0
}

[[ "$1" == "--help" ]] && show_help

###########################
### FLAGS #################
###########################

DO_NVIDIA=false
DO_INTEL=false
DO_BROADCOM=false
DO_INSTALLER=false
DO_PARTITIONS=false
DO_BOOT=false
DO_PACKAGES=false

FORCE_LOCAL=false
FORCE_PASTEBIN=false

###########################
### PARSE OPTIONS #########
###########################

if [[ $# -gt 0 ]]; then
    INTERACTIVE=false
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -nv|--nvidia) DO_NVIDIA=true ;;
            -in|--intel) DO_INTEL=true ;;
            -bc|--broadcom) DO_BROADCOM=true ;;
            -inst|--installer) DO_INSTALLER=true ;;
            -part|--partitions) DO_PARTITIONS=true ;;
            -boot|--bootlog) DO_BOOT=true ;;
            -pkg|--packages) DO_PACKAGES=true ;;
            -all|--all)
                DO_NVIDIA=true
                DO_INTEL=true
                DO_BROADCOM=true
                DO_INSTALLER=true
                DO_PARTITIONS=true
                DO_BOOT=true
                DO_PACKAGES=true
            ;;
            --local) FORCE_LOCAL=true ;;
            --pastebin) FORCE_PASTEBIN=true ;;
            --help) show_help ;;
            *)
                echo "Unknown option: $1"
                echo "Use --help to see valid options"
                exit 1
            ;;
        esac
        shift
    done
else
    INTERACTIVE=true
fi

###########################
### SUPPORT FUNCTIONS #####
###########################

# Ask user (interactive only)
ask() {
    if ! $INTERACTIVE; then return 1; fi  # <-- non-interactive: always false
    read -rp "$1 (y/n): " ans
    [[ "$ans" =~ ^[Yy]$ ]]
}

add_header() {
    echo -e "\n\n===== $1 =====" >> "$outfile"
}

###########################
### REPORT HEADER #########
###########################

{
echo "=== System Information Report ==="
echo "Generated: $timestamp"
echo "Hostname : $(hostname)"
echo "Kernel   : $(uname -r)"
echo "User     : $USER"
echo "Script   : sysinfo-collector v$SCRIPT_VERSION"
echo "====================================="
} >> "$outfile"

###########################
### COLLECTION TASKS ######
###########################

# GPU info (inxi -Gaz) only once
if [ "$DO_NVIDIA" = true ] || [ "$DO_INTEL" = true ] || ask "Collect GPU information?"; then
    add_header "GPU Info: inxi -Gaz"
    inxi -Gaz >> "$outfile" 2>&1
fi

# NVIDIA packages
if [ "$DO_NVIDIA" = true ]; then
    add_header "NVIDIA: pacman -Qs nvidia"
    pacman -Qs nvidia >> "$outfile" 2>&1
fi

# Intel packages
if [ "$DO_INTEL" = true ]; then
    add_header "Intel: pacman -Qs intel"
    pacman -Qs intel >> "$outfile" 2>&1
fi

# Broadcom
if [ "$DO_BROADCOM" = true ] || ask "Collect Broadcom WiFi information?"; then
    add_header "Broadcom: inxi -Naz"
    inxi -Naz >> "$outfile" 2>&1
    add_header "Broadcom: pacman -Qs broadcom"
    pacman -Qs broadcom >> "$outfile" 2>&1
fi

# Installer log
if [ "$DO_INSTALLER" = true ] || ask "Collect EndeavourOS installer log? (requires sudo)"; then
    add_header "Installer Log: /var/log/endeavour-install.log"
    sudo cat /var/log/endeavour-install.log >> "$outfile" 2>&1
fi

# Partition info
if [ "$DO_PARTITIONS" = true ] || ask "Collect partition info? (requires sudo)"; then
    add_header "Partition Info: fdisk -l"
    sudo fdisk -l >> "$outfile" 2>&1
    add_header "Partition Info: /etc/fstab"
    cat /etc/fstab >> "$outfile" 2>&1
fi

# Boot log
if [ "$DO_BOOT" = true ] || ask "Collect boot log (journalctl -b -0)?"; then
    add_header "Boot Log: journalctl -b -0"
    journalctl -b -0 >> "$outfile" 2>&1
fi

# Installed packages
if [ "$DO_PACKAGES" = true ] || ask "Collect installed packages list?"; then
    add_header "Installed Packages: pacman -Qq"
    pacman -Qq >> "$outfile" 2>&1
fi

###########################
### OUTPUT HANDLING #######
###########################

echo
echo "=== Report creation finished ==="
echo "File saved at: $outfile"
echo

# Non-interactive forced modes
if $FORCE_LOCAL; then
    echo "--local specified: storing file locally."
    echo "$outfile"
    exit 0
fi

if $FORCE_PASTEBIN; then
    echo "--pastebin specified: uploading via eos-sendlog..."
    result=$(cat "$outfile" | eos-sendlog 2>&1)
    echo "Upload result:"
    echo "$result"
    exit 0
fi

# Interactive upload prompt
if $INTERACTIVE; then
    read -rp "Upload via eos-sendlog instead of saving locally? (y/n): " upload
    if [[ "$upload" =~ ^[Yy]$ ]]; then
        echo "Uploading..."
        result=$(cat "$outfile" | eos-sendlog 2>&1)
        echo "Upload result:"
        echo "$result"
        exit 0
    fi
fi

echo "Report stored locally at:"
echo "$outfile"
echo "Done."
