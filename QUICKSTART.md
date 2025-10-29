# CGS Quick Start Guide

## 🎯 What is CGS?

**CGS (Concrete Constraint Guided Symbolic Execution)** is a novel search strategy for symbolic execution that uses concrete execution traces to guide the exploration of program paths. It analyzes branch dependencies to prioritize paths that are more likely to discover new behaviors.

## ✅ Your Setup is Complete!

All components are installed and ready:
- ✅ **LLVM 11.1.0** - Compiler toolchain for generating LLVM bitcode
- ✅ **IDA Pass** - Interprocedural Dependency Analysis (libidapass.so)
- ✅ **KLEE** - Symbolic execution engine (running in Docker)
- ✅ **Python Tools** - wllvm, flask for instrumentation
- ✅ **Environment** - All paths configured in env.sh

---

## 🚀 Quick 5-Minute Test

### Step 1: Load the Environment
```bash
source /workspaces/cgs/env.sh
```

### Step 2: Compile the Test Program
```bash
cd /workspaces/cgs
clang -emit-llvm -c -g -O0 test_example.c -o test_example.bc
```

### Step 3: Run KLEE Symbolic Execution
```bash
# Run with symbolic arguments (explores all paths)
./klee-docker.sh --sym-args 0 2 4 test_example.bc

# View the results
ls -la klee-last/
cat klee-last/info
```

**What just happened?**
- KLEE explored all possible execution paths through `test_example.c`
- It generated test cases for each unique path
- Results are in `klee-out-N/` (symlinked to `klee-last/`)

### Step 4: Examine Test Cases
```bash
# See generated test cases
ls klee-last/*.ktest

# View a specific test case
ktest-tool klee-last/test000001.ktest

# Replay a test case (compile native binary first)
gcc test_example.c -o test_example
klee-replay test_example klee-last/test000001.ktest
```

---

## 📖 Understanding the Test Program

The `test_example.c` program has **4 distinct paths** based on input values:

```c
int process_data(int x, int y) {
    if (x > 100) {
        if (y < 50) {
            return x + y;  // Path 1: x > 100 && y < 50
        } else {
            return x - y;  // Path 2: x > 100 && y >= 50
        }
    } else {
        if (y > 200) {
            return x * 2;  // Path 3: x <= 100 && y > 200
        } else {
            return y * 2;  // Path 4: x <= 100 && y <= 200
        }
    }
}
```

KLEE will find inputs to exercise all 4 paths!

---

## 🔬 Full CGS Workflow

The CGS methodology has **two main phases**:

### Phase 1: Dependency Analysis (IDA Pass)
Analyzes the program to identify branch dependencies:
```bash
python3 run.py <program> gen
```

**What it does:**
1. Loads the LLVM bitcode
2. Runs interprocedural dependency analysis
3. Generates dependency graphs
4. Stores metadata for the symbolic execution phase

### Phase 2: Symbolic Execution
Executes the program symbolically using the dependency information:
```bash
python3 run.py <program> run <searcher>
```

**Available Search Strategies:**
- **`cgs`** - Concrete Constraint Guided (the novel approach) ⭐
- **`random-path`** - Random path selection (baseline)
- **`dfs`** - Depth-first search
- **`bfs`** - Breadth-first search
- **`nurs:covnew`** - Coverage-optimized (targets new code)

---

## 💻 Complete Example: Testing with Simple Program

### The Test Program
The test program is already created at `/workspaces/cgs/test_example.c`. View it:
```bash
cat /workspaces/cgs/test_example.c
```

### Compile to LLVM Bitcode
```bash
source /workspaces/cgs/env.sh
cd /workspaces/cgs

# Compile to bitcode
clang -emit-llvm -c -g -O0 test_example.c -o test_example.bc

# View the LLVM IR (optional)
llvm-dis test_example.bc -o test_example.ll
less test_example.ll
```

### Run with Different Searchers

**Using KLEE directly (via Docker):**
```bash
# Random path search (baseline)
./klee-docker.sh --search=random-path --sym-args 0 2 4 test_example.bc

# Depth-first search
./klee-docker.sh --search=dfs --sym-args 0 2 4 test_example.bc

# Coverage-optimized search
./klee-docker.sh --search=nurs:covnew --sym-args 0 2 4 test_example.bc
```

**Compare Results:**
```bash
# Check how many paths were explored
grep "completed paths" klee-out-*/info

# Check instruction coverage
grep "instructions" klee-out-*/info

# See execution time
grep "elapsed time" klee-out-*/info
```

---

## 🏆 Working with Real Benchmarks

### Available Benchmarks
Edit `/workspaces/cgs/benchmark/config.txt` to see configured programs:
- **grep** - Text search (GNU grep)
- **sed** - Stream editor
- **make** - Build automation tool
- **readelf** - ELF file reader
- **objcopy** - Binary object copier
- **gawk** - AWK interpreter
- **nasm** - Assembler
- **sqlite3** - Database engine

### Benchmark Workflow

#### 1. Download and Build a Benchmark
```bash
cd /workspaces/cgs/benchmark
bash prepare.sh grep
```

This will:
- Download the source code
- Compile with `wllvm` to generate bitcode
- Compile with UBSan for bug detection
- Place binaries in the appropriate directories

#### 2. Generate Dependency Analysis
```bash
cd /workspaces/cgs
python3 run.py grep gen
```

Output: Creates dependency metadata files in `/tmp/`

#### 3. Run CGS Symbolic Execution
```bash
python3 run.py grep run cgs
```

This runs for **2 hours** (configurable in `run.py`) and outputs results to `/workspaces/cgs/results/`

#### 4. Compare with Baseline
```bash
# Run with random-path searcher
python3 run.py grep run random-path

# Compare results
ls results/grep-*/
diff results/grep-cgs/ results/grep-random-path/
```

---

## 🔧 KLEE Advanced Usage

### Symbolic Input Options

**Command-line arguments:**
```bash
# Symbolic arguments: min_args, max_args, arg_length
./klee-docker.sh --sym-args 0 2 10 program.bc
# Creates 0-2 arguments, each up to 10 bytes long
```

**Symbolic files:**
```bash
# Create 1 symbolic file of 100 bytes
./klee-docker.sh --sym-files 1 100 program.bc
```

**Symbolic standard input:**
```bash
# 50 bytes of symbolic stdin
./klee-docker.sh --sym-stdin 50 program.bc
```

**Combined example:**
```bash
./klee-docker.sh \
    --sym-args 0 2 10 \
    --sym-files 1 100 \
    --sym-stdin 20 \
    --max-time=60 \
    program.bc
```

### POSIX Runtime Options
```bash
# For programs that use POSIX APIs
docker run --rm -v $PWD:/workspace -w /workspace cgs-klee \
    klee --libc=uclibc --posix-runtime --sym-files 2 50 program.bc
```

### Time and Memory Limits
```bash
./klee-docker.sh \
    --max-time=300 \              # Run for 5 minutes
    --max-memory=4096 \           # Use up to 4GB RAM
    --max-solver-time=30 \        # Solver timeout per query
    program.bc
```

---

## 📊 Understanding the Results

### Output Directory Structure
```
klee-out-0/
├── assembly.ll          # LLVM assembly of tested program
├── info                 # Summary statistics
├── messages.txt         # KLEE's output messages
├── run.stats            # Detailed statistics over time
├── test000001.ktest     # Test case 1
├── test000002.ktest     # Test case 2
├── ...
└── warnings.txt         # Any warnings generated
```

### Key Statistics to Check

**Coverage:**
```bash
grep "KLEE: done:" klee-last/messages.txt
# Shows: paths completed, generated tests, instructions covered
```

**Errors Found:**
```bash
ls klee-last/*.err
# Each .err file represents a bug or assertion failure
```

**Test Case Details:**
```bash
ktest-tool klee-last/test000001.ktest
# Shows: object types, sizes, and concrete values
```

---

## ⚙️ Configuring CGS Parameters

Edit `/workspaces/cgs/run.py` to tune CGS behavior:

```python
# Maximum execution time (seconds)
MAX_TIME = 3600 * 2  # 2 hours

# CGS-specific parameters
TARGET_BRANCH_NUM = 10              # Number of target branches to focus on
TARGET_BRANCH_UPDATE_INSTS = 300000 # Instructions before updating targets

# Enable coverage statistics
COV_STATS = False  # Set to True for detailed branch coverage

# Optimization level
OPTIMIZE = False   # Set to True to optimize bitcode before analysis
```

### Understanding CGS Parameters

**`TARGET_BRANCH_NUM`**: How many branches to prioritize at once
- Lower (5-10): More focused, potentially faster convergence
- Higher (20-50): More exploratory, better for complex programs

**`TARGET_BRANCH_UPDATE_INSTS`**: How often to re-evaluate targets
- Lower (100K): More adaptive, higher overhead
- Higher (500K): More stable, less overhead

---

## 🐛 Troubleshooting

### Issue: "klee: error while loading shared libraries"
**Solution:** Use the Docker wrapper instead:
```bash
./klee-docker.sh [options] program.bc
```

### Issue: Environment not loaded
**Solution:** Always source env.sh in new terminals:
```bash
source /workspaces/cgs/env.sh
```

### Issue: KLEE Docker image not found
**Solution:** Rebuild the setup:
```bash
cd /workspaces/cgs
bash setup.sh
```

### Issue: Program crashes during symbolic execution
**Possible causes:**
1. Missing symbolic input annotations
2. Unsupported system calls
3. External library dependencies

**Debug steps:**
```bash
# Run with verbose output
./klee-docker.sh --debug-print-instructions=all:stderr program.bc

# Check for warnings
cat klee-last/warnings.txt

# Try with simpler inputs
./klee-docker.sh --sym-args 0 1 4 program.bc
```

---

## 📚 Additional Resources

### Files and Directories
- **`/workspaces/cgs/env.sh`** - Environment loader
- **`/workspaces/cgs/run.py`** - Main CGS orchestration script
- **`/workspaces/cgs/klee-docker.sh`** - KLEE Docker wrapper
- **`/workspaces/cgs/IDA/`** - Dependency analysis source code
- **`/workspaces/cgs/benchmark/`** - Benchmark programs
- **`/workspaces/cgs/results/`** - Symbolic execution output
- **`/workspaces/cgs/klee/`** - KLEE source code

### Docker Commands
```bash
# Check Docker image
docker images | grep cgs-klee

# Run KLEE interactively
docker run -it --rm -v $PWD:/workspace -w /workspace cgs-klee bash

# Inside container, you have access to:
klee --version
llvm-config --version
opt --version
```

### Useful LLVM Commands
```bash
# View bitcode as human-readable IR
llvm-dis program.bc -o program.ll

# Optimize bitcode
opt -O3 program.bc -o program-opt.bc

# Get bitcode statistics
llvm-nm program.bc

# Run IDA pass manually
opt -load /workspaces/cgs/IDA/build/libidapass.so \
    -ida-analysis program.bc -o /dev/null
```

---

## 🎓 Learning Path

### Beginner
1. ✅ Complete the 5-minute test above
2. Read about symbolic execution basics
3. Try modifying `test_example.c` and re-run
4. Experiment with different KLEE options

### Intermediate
1. Build and test a simple benchmark (e.g., grep)
2. Compare CGS vs random-path results
3. Analyze the dependency graphs generated
4. Try creating your own test programs

### Advanced
1. Study the CGS algorithm in the research paper
2. Modify CGS parameters for different programs
3. Add new benchmarks to config.txt
4. Extend the IDA pass for custom analyses

---

## 📝 Quick Reference Commands

```bash
# Setup (one time)
bash /workspaces/cgs/setup.sh

# Load environment (every new terminal)
source /workspaces/cgs/env.sh

# Compile to bitcode
clang -emit-llvm -c -g -O0 program.c -o program.bc

# Run KLEE
./klee-docker.sh --sym-args 0 2 10 program.bc

# Examine results
ls klee-last/
ktest-tool klee-last/test000001.ktest

# Run CGS workflow
python3 run.py <program> gen
python3 run.py <program> run cgs

# Compare searchers
python3 run.py <program> run random-path
python3 run.py <program> run cgs
diff results/<program>-*/
```

---

## 🚀 Ready to Go!

You're all set to explore symbolic execution with CGS!

**Next steps:**
1. Try the 5-minute test above
2. Experiment with different KLEE options  
3. Build a real benchmark program
4. Compare CGS against baseline searchers

**Questions?** Check the original README.md or research paper for more details.

**Happy exploring!** 🎉
