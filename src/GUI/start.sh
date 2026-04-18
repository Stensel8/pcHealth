#!/usr/bin/env bash
# ============================================================================
# pcHealth — GUI Launcher (Linux)
# The GUI is a WinUI 3 application and is not available on Linux.
# ============================================================================

echo ''
echo '[pcHealth] The GUI application is not available on Linux.'
echo '           pcHealth requires Windows build 26200 or higher.'
echo ''
echo '  To use pcHealth on Linux, run the CLI instead:'
echo "  $(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../CLI/start.sh"
echo ''
exit 1
