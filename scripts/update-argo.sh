#!/usr/bin/env bash

set -e

usage() {
  echo "Usage: $0 -b <branch> [-a <application>] [-n <namespace>]"
  echo ""
  echo "  -b    Branch name (required)"
  echo "  -a    Specific Argo CD Application (optional)"
  echo "  -n    Namespace (default: argocd)"
  exit 1
}

# Defaults
NAMESPACE="argocd"
BRANCH=""
APP=""

while getopts "b:a:n:" opt; do
  case ${opt} in
    b ) BRANCH=$OPTARG ;;
    a ) APP=$OPTARG ;;
    n ) NAMESPACE=$OPTARG ;;
    * ) usage ;;
  esac
done

if [ -z "$BRANCH" ]; then
  echo "⚠️ Branch (-b) not entered, using default: 'main'"
  BRANCH="main"
fi

sync_app() {
  local app_name=$1

  echo "🚀 Syncing $app_name..."

  kubectl annotate application "$app_name" \
    -n "$NAMESPACE" \
    argocd.argoproj.io/refresh=hard --overwrite

  echo "✅ Synced $app_name"
}

update_app() {
  local app_name=$1

  echo "🔄 Updating $app_name to branch '$BRANCH'..."

  # Check if app uses spec.sources (multi-source)
  MULTI_SOURCE=$(kubectl get application "$app_name" -n "$NAMESPACE" -o jsonpath='{.spec.sources}')

  if [ -n "$MULTI_SOURCE" ]; then
    echo "📚 Detected multi-source application"

    # Count number of sources
    SOURCE_COUNT=$(kubectl get application "$app_name" -n "$NAMESPACE" -o json | jq '.spec.sources | length')

    for ((i=0; i<SOURCE_COUNT; i++)); do
      kubectl patch application "$app_name" \
        -n "$NAMESPACE" \
        --type json \
        -p "[{\"op\": \"replace\", \"path\": \"/spec/sources/$i/targetRevision\", \"value\": \"$BRANCH\"}]"
    done

  else
    echo "📄 Detected single-source application"

    kubectl patch application "$app_name" \
      -n "$NAMESPACE" \
      --type merge \
      -p "{\"spec\": {\"source\": {\"targetRevision\": \"$BRANCH\"}}}"
  fi

  echo "✅ Updated $app_name"

  sync_app "$app_name"
}

if [ -n "$APP" ]; then
  update_app "$APP"
else
  echo "📦 Fetching all applications in namespace '$NAMESPACE'..."
  APPS=$(kubectl get applications -n "$NAMESPACE" -o jsonpath='{.items[*].metadata.name}')

  if [ -z "$APPS" ]; then
    echo "⚠️  No applications found."
    exit 0
  fi

  for app in $APPS; do
    update_app "$app"
  done
fi

echo "🎉 All done."