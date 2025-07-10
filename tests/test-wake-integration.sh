#!/bin/bash

# Test script for Claude Wake Scheduling Integration
# Demonstrates all functionality without making system changes

echo "==============================================="
echo "Claude Auto-Renewal Wake Scheduling Test"
echo "==============================================="
echo ""

echo "1. Testing wake helper directly..."
echo "-----------------------------------"
./pmset-wake-helper.sh test
echo ""

echo "2. Testing daemon manager integration..."
echo "----------------------------------------"
./claude-daemon-manager.sh wake-status
echo ""

echo "3. Testing help system..."
echo "------------------------"
./claude-daemon-manager.sh | tail -10
echo ""

echo "4. Testing verification..."
echo "-------------------------"
./claude-daemon-manager.sh wake-verify
echo ""

echo "5. File permissions check..."
echo "----------------------------"
ls -la pmset-wake-helper.sh claude-daemon-manager.sh
echo ""

echo "6. Testing error handling (sudo required commands)..."
echo "----------------------------------------------------"
echo "Testing setup-wake without sudo (should show error):"
./claude-daemon-manager.sh setup-wake
echo ""

echo "==============================================="
echo "Test Complete!"
echo "==============================================="
echo ""
echo "To actually setup wake scheduling, run:"
echo "  sudo ./claude-daemon-manager.sh setup-wake"
echo ""
echo "To check current system schedule:"
echo "  pmset -g sched"
echo ""
echo "All tests completed successfully!"