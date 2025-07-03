# Firefox - Detection script
$paths = @(
    "C:\Program Files\Mozilla Firefox\uninstall\helper.exe",
    "C:\Program Files (x86)\Mozilla Firefox\uninstall\helper.exe"
)

foreach ($path in $paths) {
    if (Test-Path $path) {
        exit 1  # Non-compliant: helper.exe found
    }
}

exit 0  # Compliant: helper.exe not found
