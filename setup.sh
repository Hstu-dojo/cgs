#!/bin/bash

# CGS Complete Setup Script
# This script installs all dependencies and builds the entire CGS application
# Uses Docker for KLEE to avoid C++17/GCC compatibility issues

# Don't exit on error for apt-get commands
set +e

echo "========================================="
echo "CGS Complete Setup Script"
echo "========================================="
echo ""
echo "Note: This script uses Docker for KLEE to ensure compatibility"
echo ""

# Change to workspace directory
cd /workspaces/cgs

# Step 1: Download and install LLVM 11.1.0
echo "[1/6] Downloading and installing LLVM 11.1.0..."
if [ ! -d "clang+llvm-11.1.0-x86_64-linux-gnu-ubuntu-16.04" ]; then
    wget -q -O llvm.tar.xz https://github.com/llvm/llvm-project/releases/download/llvmorg-11.1.0/clang+llvm-11.1.0-x86_64-linux-gnu-ubuntu-16.04.tar.xz
    tar -xf llvm.tar.xz
    rm llvm.tar.xz
    echo "✓ LLVM 11.1.0 installed"
else
    echo "✓ LLVM 11.1.0 already exists"
fi

# Set environment variables
export LLVM_DIR=/workspaces/cgs/clang+llvm-11.1.0-x86_64-linux-gnu-ubuntu-16.04
export PATH=$LLVM_DIR/bin:$PATH
export LD_LIBRARY_PATH=$LLVM_DIR/lib:$LD_LIBRARY_PATH
export SOURCE_DIR=/workspaces/cgs
export SANDBOX_DIR=/tmp
export OUTPUT_DIR=/workspaces/cgs/results

echo "✓ Environment variables set"

# Step 2: Install Python dependencies
echo ""
echo "[2/6] Installing Python dependencies..."
pip3 install -q wllvm flask
echo "✓ Python dependencies installed"

# Step 3: Install system dependencies
echo ""
echo "[3/6] Installing system dependencies..."
sudo apt-get update -qq > /dev/null 2>&1 || true
sudo apt-get install -y \
    build-essential \
    cmake \
    curl \
    file \
    libcap-dev \
    libgoogle-perftools-dev \
    libncurses5-dev \
    libsqlite3-dev \
    libtcmalloc-minimal4 \
    python3-pip \
    unzip \
    graphviz \
    doxygen \
    bison \
    flex \
    libboost-all-dev \
    perl \
    zlib1g-dev \
    minisat 2>&1 | grep -E "(Setting up|Reading)" | tail -5 || true
echo "✓ System dependencies installed (STP will be built from source)"

# Step 4: Build IDA
echo ""
echo "[4/7] Building IDA (Branch Dependency Analysis)..."
cd /workspaces/cgs/IDA
rm -rf build
mkdir build
cd build
CMAKE_PREFIX_PATH=$LLVM_DIR cmake .. > /dev/null
make -j$(nproc) > /dev/null 2>&1
if [ -f "libidapass.so" ]; then
    echo "✓ IDA built successfully"
else
    echo "✗ IDA build failed"
    exit 1
fi

# Step 5: Check Docker availability
echo ""
echo "[5/7] Checking Docker..."
if ! command -v docker &> /dev/null; then
    echo "✗ Docker not found. Please install Docker to build KLEE."
    echo "  On GitHub Codespaces/Dev Containers, Docker should be available."
    exit 1
fi
echo "✓ Docker is available"

# Step 6: Build KLEE using Docker
echo ""
echo "[6/7] Building KLEE with Docker (this may take 10-15 minutes)..."
cd /workspaces/cgs/klee

# Apply compatibility fixes to KLEE source before building
echo "  Applying C++17 compatibility fixes..."
# Fix Statistic.h
if ! grep -q "#include <cstdint>" include/klee/Statistics/Statistic.h; then
    sed -i '/#define KLEE_STATISTIC_H/a #include <cstdint>' include/klee/Statistics/Statistic.h
fi

# Fix Interpreter.h
if ! grep -q "#include <cstdint>" include/klee/Core/Interpreter.h; then
    sed -i '/#define KLEE_INTERPRETER_H/a #include <cstdint>' include/klee/Core/Interpreter.h
fi

# Fix Statistics.cpp
if ! grep -q "#include <cstdint>" lib/Basic/Statistics.cpp; then
    sed -i '/#include "klee\/Statistics\/Statistics.h"/a #include <cstdint>' lib/Basic/Statistics.cpp
fi

echo "  Building Docker image..."
if docker build -t cgs-klee . > /tmp/klee_docker_build.log 2>&1; then
    echo "✓ KLEE Docker image built successfully"
    
    # Extract KLEE binaries from Docker image
    echo "  Extracting KLEE binaries from Docker image..."
    mkdir -p /workspaces/cgs/klee/build/bin
    
    # Create a temporary container and copy the binaries
    CONTAINER_ID=$(docker create cgs-klee)
    docker cp $CONTAINER_ID:/home/klee/klee_build/bin/. /workspaces/cgs/klee/build/bin/ 2>/dev/null || true
    docker cp $CONTAINER_ID:/home/klee/klee_build/lib/. /workspaces/cgs/klee/build/lib/ 2>/dev/null || true
    docker rm $CONTAINER_ID > /dev/null 2>&1
    
    if [ -f "/workspaces/cgs/klee/build/bin/klee" ]; then
        echo "✓ KLEE binaries extracted successfully"
    else
        echo "⚠ KLEE built in Docker (use: docker run -it cgs-klee)"
    fi
else
    echo "✗ KLEE Docker build failed. Check /tmp/klee_docker_build.log for details"
    tail -20 /tmp/klee_docker_build.log
fi

# Step 7: Create KLEE wrapper script for Docker execution
echo ""
echo "[7/7] Creating KLEE Docker wrapper..."
cat > /workspaces/cgs/klee-docker.sh << 'WRAPPER_EOF'
#!/bin/bash
# KLEE Docker Wrapper
# This script runs KLEE inside Docker container

KLEE_DOCKER_IMAGE="cgs-klee"

# Check if Docker image exists
if ! docker image inspect $KLEE_DOCKER_IMAGE &> /dev/null; then
    echo "Error: KLEE Docker image not found. Run setup.sh first."
    exit 1
fi

# Mount current directory and run KLEE
docker run --rm -it \
    -v "$PWD:/workspace" \
    -w /workspace \
    $KLEE_DOCKER_IMAGE \
    klee "$@"
WRAPPER_EOF

chmod +x /workspaces/cgs/klee-docker.sh
echo "✓ KLEE Docker wrapper created at /workspaces/cgs/klee-docker.sh"

# Create results directory
cd /workspaces/cgs
mkdir -p results

# Create environment setup script
cat > /workspaces/cgs/env.sh << 'EOF'
#!/bin/bash
export LLVM_DIR=/workspaces/cgs/clang+llvm-11.1.0-x86_64-linux-gnu-ubuntu-16.04
export PATH=$LLVM_DIR/bin:$PATH
export LD_LIBRARY_PATH=$LLVM_DIR/lib:$LD_LIBRARY_PATH
export SOURCE_DIR=/workspaces/cgs
export SANDBOX_DIR=/tmp
export OUTPUT_DIR=/workspaces/cgs/results

# Add KLEE to PATH if binaries were extracted
if [ -f "/workspaces/cgs/klee/build/bin/klee" ]; then
    export PATH=/workspaces/cgs/klee/build/bin:$PATH
    echo "CGS environment loaded (KLEE binaries available)"
else
    echo "CGS environment loaded (use klee-docker.sh or docker run cgs-klee)"
fi
EOF
chmod +x /workspaces/cgs/env.sh

# Final status
echo ""
echo "========================================="
echo "Setup Complete!"
echo "========================================="
echo ""
echo "Component Status:"
[ -d "/workspaces/cgs/clang+llvm-11.1.0-x86_64-linux-gnu-ubuntu-16.04" ] && echo "  ✓ LLVM 11.1.0"
[ -f "/workspaces/cgs/IDA/build/libidapass.so" ] && echo "  ✓ IDA (libidapass.so)"
if docker image inspect cgs-klee &> /dev/null; then
    echo "  ✓ KLEE (Docker image: cgs-klee)"
    [ -f "/workspaces/cgs/klee/build/bin/klee" ] && echo "  ✓ KLEE binaries extracted"
else
    echo "  ✗ KLEE Docker image not built"
fi
[ -f "/workspaces/cgs/klee-docker.sh" ] && echo "  ✓ KLEE Docker wrapper"
[ -f "/workspaces/cgs/sandbox.tgz" ] && echo "  ✓ sandbox.tgz"

echo ""
echo "To use CGS in new terminal sessions:"
echo "  source /workspaces/cgs/env.sh"
echo ""
echo "To generate dependency analysis:"
echo "  python3 run.py <program> gen"
echo ""
echo "To run symbolic execution with KLEE:"
if [ -f "/workspaces/cgs/klee/build/bin/klee" ]; then
    echo "  python3 run.py <program> run <searcher>"
else
    echo "  ./klee-docker.sh [klee-options] <program.bc>"
    echo "  OR"
    echo "  docker run --rm -v \$PWD:/workspace -w /workspace cgs-klee klee <program.bc>"
fi
echo ""
echo "Available searchers: cgs, random-path, dfs, bfs, nurs:covnew"
echo ""
