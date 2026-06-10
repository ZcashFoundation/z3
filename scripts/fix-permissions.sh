#!/usr/bin/env bash
#
# Permission fix utility for Z3 stack local volumes
# This script sets correct ownership and permissions on user-specified directories
#
# Usage:
#   ./fix-permissions.sh <service> <directory_path>
#
# Services: zebra, zaino, zallet, zcashd, cookie
#
# Examples:
#   ./fix-permissions.sh zebra /mnt/ssd/zebra-state
#   ./fix-permissions.sh zaino /home/user/data/zaino
#   ./fix-permissions.sh zallet ~/Documents/zallet-data
#   ./fix-permissions.sh zcashd /mnt/ssd/zcashd-data
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
ZALLET_UID=1000
ZALLET_GID=1000
ZCASHD_UID=2001
ZCASHD_GID=2001

# Show usage
usage() {
    echo "Usage: $0 <service> <directory_path>"
    echo ""
    echo "Services:"
    echo "  zebra   - Zebra blockchain state (UID:GID 10001:10001, perms 700)"
    echo "  zaino   - Zaino indexer data (UID:GID 1000:1000, perms 700)"
    echo "  zallet  - Zallet wallet data (UID:GID 1000:1000, perms 700)"
    echo "  zcashd  - Optional zcashd comparator data (UID:GID 2001:2001, perms 700)"
    echo "  cookie  - Shared cookie directory (UID:GID 10001:10001, perms 750)"
    echo ""
    echo "Examples:"
    echo "  $0 zebra /mnt/ssd/zebra-state"
    echo "  $0 zaino /home/user/data/zaino"
    echo "  $0 zallet ~/Documents/zallet-data"
    echo "  $0 zcashd /mnt/ssd/zcashd-data"
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
    zcashd)
        OWNER_UID=$ZCASHD_UID
        OWNER_GID=$ZCASHD_GID
        PERMS=700
        ;;
    cookie)
        OWNER_UID=$ZEBRA_UID
        OWNER_GID=$ZEBRA_GID
        PERMS=755
        echo -e "${YELLOW}NOTE: cookie permissions are handled by the cookie-permissions${NC}"
        echo "sidecar in docker-compose.yml at runtime. It chmods the .cookie file to"
        echo "0644 inside the volume so any consumer uid can read it. Bind-mounting"
        echo "the cookie path is advanced; the default Docker named volume is preferred."
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
        echo "  Z3_CHAIN_DATA_PATH=${DIR_PATH}"
        ;;
    zaino)
        echo "  Z3_ZAINO_DATA_PATH=${DIR_PATH}"
        ;;
    zallet)
        echo "  Z3_ZALLET_DATA_PATH=${DIR_PATH}"
        ;;
    zcashd)
        echo "  Z3_ZCASHD_DATA_PATH=${DIR_PATH}"
        ;;
    cookie)
        echo "  Z3_COOKIE_PATH=${DIR_PATH}"
        ;;
esac
echo ""
