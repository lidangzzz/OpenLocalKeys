#!/bin/bash

# OpenLocalKeys convenience script

ACTION=${1:-"run"}

case "$ACTION" in
  "app"|"openlocalkeys"|"gui")
    echo "Starting OpenLocalKeys app..."
    swift run OpenLocalKeys
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
    echo "  app, openlocalkeys, gui    Build and run the macOS app"
    echo "  cli, olkeys               Run the CLI tool (passes args through)"
    echo "  build                     Build all targets"
    echo "  test                      Run all tests"
    echo "  clean                     Clean build artifacts"
    echo "  help, -h, --help          Show this help"
    echo ""
    echo "Examples:"
    echo "  ./run.sh app              # Start the macOS app"
    echo "  ./run.sh cli              # Run CLI client"
    echo "  ./run.sh cli --status     # Check server status"
    echo "  ./run.sh test             # Run tests"
    ;;
  *)
    echo "Unknown command: $ACTION"
    echo "Run './run.sh help' for usage"
    exit 1
    ;;
esac
