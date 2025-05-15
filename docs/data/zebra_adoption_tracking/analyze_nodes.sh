#!/bin/bash
#set -x

# Download nodes as HTML from https://mainnet.zcashexplorer.app/nodes with error handling
if ! wget -q -O memory-bank/data/zebra_adoption_tracking/nodes.html https://mainnet.zcashexplorer.app/nodes; then
    echo "Error: Failed to download nodes HTML file."
    exit 1
fi
wget -q -O memory-bank/data/zebra_adoption_tracking/nodes.html https://mainnet.zcashexplorer.app/nodes

# Read the local HTML file
html_content=$(cat memory-bank/data/zebra_adoption_tracking/nodes.html)

# Extract lines containing version information and then the version string
versions=$(echo "$html_content" | grep '/Zebra:\|/MagicBean:' | sed 's/.*\/\(Zebra\|MagicBean\):[^/]*\/.*/\1/')

# Count Zebra and MagicBean nodes
zebra_count=$(echo "$versions" | grep -c 'Zebra')
magicbean_count=$(echo "$versions" | grep -c 'MagicBean')

# Calculate total nodes
total_nodes=$((zebra_count + magicbean_count))

# Calculate percentages
if [ "$total_nodes" -eq 0 ]; then
    zebra_percentage=0
    magicbean_percentage=0
else
    zebra_percentage=$(awk "BEGIN { printf \"%.2f\", ($zebra_count * 100 / $total_nodes) }")
    magicbean_percentage=$(awk "BEGIN { printf \"%.2f\", ($magicbean_count * 100 / $total_nodes) }")
fi

# Output the results
echo "Total nodes: $total_nodes"
echo "Zebra nodes: $zebra_count ($zebra_percentage%)"
echo "MagicBean nodes: $magicbean_count ($magicbean_percentage%)"
