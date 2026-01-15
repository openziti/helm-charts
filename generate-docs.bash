#!/bin/bash
set -e

# Ensure helm-docs is installed
if ! command -v helm-docs &> /dev/null; then
    echo "helm-docs could not be found. Please install it first."
    echo "Go install: go install github.com/norwoodj/helm-docs/cmd/helm-docs@latest"
    exit 1
fi

SCRIPT_DIR=$(cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd)
REPO_ROOT=$(dirname "$SCRIPT_DIR")
CHARTS_DIR="$REPO_ROOT/charts"

echo "Using helm-docs version: $(helm-docs --version)"

# Find all ziti-* charts
for chart in "$CHARTS_DIR"/ziti-*; do
    if [ -d "$chart" ]; then
        chart_name=$(basename "$chart")
        echo "Processing $chart_name..."
        
        # Run helm-docs
        helm-docs --chart-search-root "$chart"
        
        # Run linter on the generated README.md
        readme="$chart/README.md"
        if [ -f "$readme" ]; then
            echo "Linting $readme..."
            "$SCRIPT_DIR/check_mdx.py" "$readme"
        else
            echo "Warning: No README.md found for $chart_name after running helm-docs"
        fi
        
        echo "Done with $chart_name"
        echo "----------------------------------------"
    fi
done

echo "All ziti-* charts processed."
