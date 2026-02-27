#!/bin/bash

# OpenLocalKeys convenience script

ACTION=${1:-"run"}

case "$ACTION" in
  "app"|"unix"|"socket"|"openlocalkeys")
    echo "Starting OpenLocalKeys (Unix Socket) app..."
    swift run OpenLocalKeys
    ;;
  "http")
    echo "Starting OpenLocalKeys HTTP app..."
    swift run OpenLocalKeysHTTP
    ;;
  "cli"|"olkeys")
    echo "Running OLKeys CLI..."
    swift run olkeys "${@:2}"
    ;;
  "build")
    echo "Building OpenLocalKeys..."
    swift build
    ;;
  "test")
    echo "Running tests..."
    swift test
    ;;
  "clean")
    echo "Cleaning build..."
    swift package clean
    ;;
  "help"|"-h"|"--help")
    echo "OpenLocalKeys Development Script"
    echo ""
    echo "Usage: ./run.sh <command> [args]"
    echo ""
    echo "Commands:"
    echo "  app, unix, socket         Build and run the Unix socket macOS app"
    echo "  http                      Build and run the HTTP macOS app"
    echo "  cli, olkeys               Run the CLI tool (passes args through)"
    echo "  build                     Build all targets"
    echo "  test                      Run all tests"
    echo "  clean                     Clean build artifacts"
    echo "  help, -h, --help          Show this help"
    echo ""
    echo "Available Applications:"
    echo "  • OpenLocalKeys           - Unix domain socket server (original)"
    echo "  • OpenLocalKeysHTTP       - HTTP server on port 8899"
    echo "  • olkeys                  - CLI client for Unix socket"
    echo ""
    echo "Examples:"
    echo "  ./run.sh app              # Start Unix socket app"
    echo "  ./run.sh http             # Start HTTP app"
    echo "  ./run.sh cli              # Run CLI client"
    echo "  ./run.sh cli --status     # Check server status"
    echo "  ./run.sh test             # Run tests"
    echo ""
    echo "Direct swift run commands:"
    echo "  swift run OpenLocalKeys      # Unix socket app"
    echo "  swift run OpenLocalKeysHTTP  # HTTP app"
    echo "  swift run olkeys             # CLI client"
    ;;
  *)
    echo "Unknown command: $ACTION"
    echo "Run './run.sh help' for usage"
    exit 1
    ;;
esac
