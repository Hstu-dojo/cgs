#!/bin/bash
# test_cgs.sh - Step-by-step test script for CGS
# This script demonstrates how to test the CGS setup

set -e  # Exit on error

echo "╔════════════════════════════════════════════════════════════════╗"
echo "║           CGS Test Script - Step by Step Demo                 ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""

# Step 1: Load environment
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "STEP 1: Loading CGS Environment"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
source /workspaces/cgs/env.sh
echo "✓ Environment loaded"
echo ""

# Step 2: Compile test program
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "STEP 2: Compiling Test Program to LLVM Bitcode"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
cd /workspaces/cgs

if [ ! -f test_example.c ]; then
    echo "✗ Error: test_example.c not found!"
    exit 1
fi

echo "Compiling test_example.c..."
clang -emit-llvm -c -g -O0 -I/workspaces/cgs/klee/include test_example.c -o test_example.bc
echo "✓ Compiled to test_example.bc"
echo ""

# Show the source code
echo "Source code preview:"
echo "────────────────────────────────────────"
head -30 test_example.c
echo "... (see test_example.c for full code)"
echo ""

# Step 3: Run KLEE
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "STEP 3: Running KLEE Symbolic Execution"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Command: ./klee-docker.sh test_example.bc"
echo ""
echo "This tells KLEE to:"
echo "  • Symbolically execute the bitcode"
echo "  • Explore all possible execution paths"
echo "  • Generate test cases for each path"
echo ""
read -p "Press Enter to start KLEE symbolic execution..."

./klee-docker.sh test_example.bc

echo ""
echo "✓ KLEE finished execution"
echo ""

# Step 4: Examine results
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "STEP 4: Examining Results"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Find the most recent klee-out directory
KLEE_OUT=$(ls -td klee-out-* 2>/dev/null | head -1)
if [ -z "$KLEE_OUT" ]; then
    echo "✗ Error: No KLEE output directory found"
    exit 1
fi

# Create symlink for convenience
ln -sf "$KLEE_OUT" klee-last

echo "Output directory: klee-last/ (symlink to latest run)"
echo ""

echo "📊 Summary Statistics:"
echo "────────────────────────────────────────"
if [ -f "klee-last/info" ]; then
    cat klee-last/info
else
    echo "✗ info file not found"
fi
echo ""

echo "📝 Generated Test Cases:"
echo "────────────────────────────────────────"
TEST_COUNT=$(ls klee-last/*.ktest 2>/dev/null | wc -l)
echo "Total test cases generated: $TEST_COUNT"
echo ""

if [ $TEST_COUNT -gt 0 ]; then
    echo "Examining first 3 test cases:"
    for testfile in $(ls klee-last/*.ktest | head -3); do
        echo ""
        echo "▸ $(basename $testfile):"
        ktest-tool "$testfile" | head -20
    done
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "STEP 5: Understanding the Results"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "KLEE explored the program and found $TEST_COUNT different paths."
echo ""
echo "The test_example.c program has 4 main branches:"
echo "  1. x > 100 && y < 50   → returns x + y"
echo "  2. x > 100 && y >= 50  → returns x - y"
echo "  3. x <= 100 && y > 200 → returns x * 2"
echo "  4. x <= 100 && y <= 200 → returns y * 2"
echo ""
echo "Each .ktest file contains concrete values that exercise a specific path."
echo ""

# Step 6: Replay test cases
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "STEP 6: Replaying Test Cases (Optional)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "To replay test cases on the native binary:"
echo "  1. Compile native binary: gcc test_example.c -o test_example"
echo "  2. Replay: klee-replay test_example klee-last/test000001.ktest"
echo ""

# Summary
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ Test Complete!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "📁 Results are in: ./klee-last/"
echo ""
echo "Next steps:"
echo "  • View detailed stats: cat klee-last/run.stats"
echo "  • Check for errors: ls klee-last/*.err"
echo "  • Read messages: cat klee-last/messages.txt"
echo "  • Try different searchers: ./klee-docker.sh --search=dfs ..."
echo ""
echo "📖 For more information, read: /workspaces/cgs/QUICKSTART.md"
echo ""
