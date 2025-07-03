# FF_reg_det.ps1 - Detection script
$logPath = "C:\tmp\FirefoxHelper.log"

if (Test-Path $logPath) {
    exit 1  # Non-compliant: FirefoxHelper.log exists
} else {
    exit 0  # Compliant: FirefoxHelper.log not found
}
