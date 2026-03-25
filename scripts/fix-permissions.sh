#!/usr/bin/env bash
#
# Permission fix utility for Z3 stack local volumes
# This script sets correct ownership and permissions on user-specified directories
#
# Usage:
#   ./fix-permissions.sh <service> <directory_path>
#
# Services: zebra, zaino, zallet, cookie
#
# Examples:
#   ./fix-permissions.sh zebra /mnt/ssd/zebra-state
#   ./fix-permissions.sh zaino /home/user/data/zaino
#   ./fix-permissions.sh zallet ~/Documents/zallet-data
#   ./fix-permissions.sh cookie /var/lib/z3/cookies
#

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Container UIDs/GIDs
ZEBRA_UID=10001
ZEBRA_GID=10001
ZAINO_UID=1000
ZAINO_GID=1000
ZALLET_UID=65532
ZALLET_GID=65532

# Show usage
usage() {
    echo "Usage: $0 <service> <directory_path>"
    echo ""
    echo "Services:"
    echo "  zebra   - Zebra blockchain state (UID:GID 10001:10001, perms 700)"
    echo "  zaino   - Zaino indexer data (UID:GID 1000:1000, perms 700)"
    echo "  zallet  - Zallet wallet data (UID:GID 65532:65532, perms 700)"
    echo "  cookie  - Shared cookie directory (UID:GID 10001:10001, perms 750)"
    echo ""
    echo "Examples:"
    echo "  $0 zebra /mnt/ssd/zebra-state"
    echo "  $0 zaino /home/user/data/zaino"
    echo "  $0 zallet ~/Documents/zallet-data"
    exit 1
}

# Check arguments
if [[ $# -ne 2 ]]; then
    usage
fi

SERVICE="$1"
DIR_PATH="$2"

# Validate service
case "$SERVICE" in
    zebra)
        OWNER_UID=$ZEBRA_UID
        OWNER_GID=$ZEBRA_GID
        PERMS=700
        ;;
    zaino)
        OWNER_UID=$ZAINO_UID
        OWNER_GID=$ZAINO_GID
        PERMS=700
        ;;
    zallet)
        OWNER_UID=$ZALLET_UID
        OWNER_GID=$ZALLET_GID
        PERMS=700
        ;;
    cookie)
        OWNER_UID=$ZEBRA_UID
        OWNER_GID=$ZEBRA_GID
        PERMS=750
        echo -e "${YELLOW}WARNING: Cookie directory has special requirements.${NC}"
        echo "Zaino (UID 1000) needs read access to Zebra's (UID 10001) cookie."
        echo "After running this script, you may need to:"
        echo "  1. Use ACLs: sudo setfacl -m u:1000:r ${DIR_PATH}"
        echo "  2. Or create a shared group for both users"
        echo "  3. Or keep cookie as Docker volume (recommended)"
        echo ""
        ;;
    *)
        echo -e "${RED}Error: Unknown service '$SERVICE'${NC}"
        usage
        ;;
esac

# Check if directory exists
if [[ ! -d "$DIR_PATH" ]]; then
    echo -e "${RED}Error: Directory does not exist: ${DIR_PATH}${NC}"
    echo "Please create the directory first:"
    echo "  mkdir -p ${DIR_PATH}"
    exit 1
fi

# Check if running with sudo
if [[ $EUID -ne 0 ]]; then
   echo -e "${YELLOW}This script needs sudo to set ownership.${NC}"
   echo "Re-running with sudo..."
   echo ""
   exec sudo "$0" "$@"
fi

echo -e "${GREEN}Z3 Stack - Fixing Permissions${NC}"
echo "Service:     $SERVICE"
echo "Directory:   $DIR_PATH"
echo "UID:GID:     ${OWNER_UID}:${OWNER_GID}"
echo "Permissions: $PERMS"
echo ""

# Set ownership and permissions
chown "${OWNER_UID}:${OWNER_GID}" "$DIR_PATH"
chmod "$PERMS" "$DIR_PATH"

echo -e "${GREEN}✓ Permissions set successfully${NC}"
echo ""
echo "To use this directory, update your .env file:"
case "$SERVICE" in
    zebra)
        echo "  Z3_ZEBRA_DATA_PATH=${DIR_PATH}"
        ;;
    zaino)
        echo "  Z3_ZAINO_DATA_PATH=${DIR_PATH}"
        ;;
    zallet)
        echo "  Z3_ZALLET_DATA_PATH=${DIR_PATH}"
        ;;
    cookie)
        echo "  Z3_COOKIE_PATH=${DIR_PATH}"
        ;;
esac
echo ""
