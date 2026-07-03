# fsregistration Benchmark Docker

Docker-based benchmarking for 3D registration methods. Two-phase design: build the workspace once, then run benchmarks on each machine.

## Quick Start

```bash
# 1. Build image (~15 min)
cd /path/to/ros_ws
docker build -f .benchmark_docker/Dockerfile -t fsbench:latest .

# 2. Build workspace (first time only, ~10 min)
docker run --rm -v /path/to/ros_ws:/home/benchmark/ros_ws fsbench:latest /usr/local/bin/docker-entrypoint-build.sh

# 3. Run a benchmark
docker run --rm \
  -v /path/to/ros_ws:/home/benchmark/ros_ws \
  -v /path/to/ros_ws/dataFolder:/data:ro \
  -v ./benchmark_results:/volume/results \
  fsbench:latest /usr/local/bin/docker-entrypoint-benchmark.sh soft 8

# 4. Quick test (10 samples per method, validates config)
bash .benchmark_docker/run_test.sh
```

## Setup on Each Server

### 1. Clone the repo
```bash
git clone <fsregistration-repo-url>
cd ros_ws
```

### 2. Build the image
```bash
docker build -f .benchmark_docker/Dockerfile -t fsbench:latest .
```
**Build time:** ~15 minutes (OpenCV 10min, PCL 5min)

### 3. Build the workspace (first time only)
```bash
docker run --rm -v /path/to/ros_ws:/home/benchmark/ros_ws fsbench:latest /usr/local/bin/docker-entrypoint-build.sh
```
This compiles soft20 + fsregistration with colcon, creates conda environments, builds pybind11, and compiles C++ wrappers. Build artifacts persist in `ros_ws/build/` and `ros_ws/install/`.

**Build time:** ~10 minutes first run, ~2 minutes on subsequent runs (cached).

### 4. Prepare data directory
```
/path/to/ros_ws/dataFolder/3dmatch/models/predator/data/indoor/  ← 3DMatch .pth point cloud files
```

### 5. Prepare weights directory
Create a `weights/` directory alongside `dataFolder/`:
```
/path/to/ros_ws/weights/
├── ├── regtr/regtr-3dmatch.pth           ← RegTR model weights
├── hybridpoint/hybridpoint-3dmatch.pth  ← HybridPoint model weights
├── predator/predator-indoor.pth       ← Predator model weights
└── geotransformer/geotransformer-3dmatch.pth  ← GeoTransformer model weights

**Weight download links:**
- **RegTR:** https://github.com/yewzijian/RegTR/releases
- **HybridPoint:** From HybridPoint repo
- **Predator:** From Predator repo (https://github.com/zhanwenchen/Predator)

## Running Benchmarks

### Command format
```bash
docker run --rm \
  -v /path/to/ros_ws:/home/benchmark/ros_ws \
  -v /path/to/ros_ws/dataFolder:/data:ro \
  -v /path/to/ros_ws/weights:/volume/weights:ro \
  -v ./benchmark_results:/volume/results \
  fsbench:latest /usr/local/bin/docker-entrypoint-benchmark.sh <method> [num_workers]
```

### Method assignment (3 machines, 7 methods)

**Machine 1:**
```bash
docker run --rm \
  -v /path/to/ros_ws:/home/benchmark/ros_ws \
  -v /path/to/ros_ws/dataFolder:/data:ro \
  -v /path/to/ros_ws/weights:/volume/weights:ro \
  -v ./results:/volume/results \
  fsbench:latest /usr/local/bin/docker-entrypoint-benchmark.sh soft
```

**Machine 2:**
```bash
docker run --rm \
  -v /path/to/ros_ws:/home/benchmark/ros_ws \
  -v /path/to/ros_ws/dataFolder:/data:ro \
  -v /path/to/ros_ws/weights:/volume/weights:ro \
  -v ./results:/volume/results \
  fsbench:latest /usr/local/bin/docker-entrypoint-benchmark.sh fpfh

docker run --rm \
  -v /path/to/ros_ws:/home/benchmark/ros_ws \
  -v /path/to/ros_ws/dataFolder:/data:ro \
  -v /path/to/ros_ws/weights:/volume/weights:ro \
  -v ./results:/volume/results \
  fsbench:latest /usr/local/bin/docker-entrypoint-benchmark.sh icp
```

**Machine 3:**
```bash
docker run --rm \
  -v /path/to/ros_ws:/home/benchmark/ros_ws \
  -v /path/to/ros_ws/dataFolder:/data:ro \
  -v /path/to/ros_ws/weights:/volume/weights:ro \
  -v ./results:/volume/results \
  fsbench:latest /usr/local/bin/docker-entrypoint-benchmark.sh geotransformer

docker run --rm \
  -v /path/to/ros_ws:/home/benchmark/ros_ws \
  -v /path/to/ros_ws/dataFolder:/data:ro \
  -v /path/to/ros_ws/weights:/volume/weights:ro \
  -v ./results:/volume/results \
  fsbench:latest /usr/local/bin/docker-entrypoint-benchmark.sh regtr

docker run --rm \
  -v /path/to/ros_ws:/home/benchmark/ros_ws \
  -v /path/to/ros_ws/dataFolder:/data:ro \
  -v /path/to/ros_ws/weights:/volume/weights:ro \
  -v ./results:/volume/results \
  fsbench:latest /usr/local/bin/docker-entrypoint-benchmark.sh hybridpoint

docker run --rm \
  -v /path/to/ros_ws:/home/benchmark/ros_ws \
  -v /path/to/ros_ws/dataFolder:/data:ro \
  -v /path/to/ros_ws/weights:/volume/weights:ro \
  -v ./results:/volume/results \
  fsbench:latest /usr/local/bin/docker-entrypoint-benchmark.sh pointreggpt
```

## Test Mode

Run a quick validation with 10 samples per method to ensure everything is configured correctly:

```bash
bash .benchmark_docker/run_test.sh
```

This script:
1. `git pull --recurse-submodules`
2. Builds the Docker image
3. Builds the workspace
4. Runs each of the 7 methods with `--test` flag (1 registration per noise/split)
   Noise levels: low_gauss, high_gauss, low_salt_pepper, high_salt_pepper, None, low, high (7 × 2 splits = 14 combos)

Results saved to `./test_results/<method>/`.

You can also run test mode for a single method:
```bash
docker run --rm \
  -v /path/to/ros_ws:/home/benchmark/ros_ws \
  -v /path/to/ros_ws/dataFolder:/data:ro \
  -v ./test_results:/volume/results \
  fsbench:latest /usr/local/bin/docker-entrypoint-benchmark.sh soft 2 --test
```

## Output Files

Each method produces CSV files in `./benchmark_results/<method>/`:

| Method | Output CSVs |
|--------|------------|
| soft | 14 CSVs (all noise/split combos) |
| fpfh | 14 CSVs (all noise/split combos) |
| icp | 14 CSVs (all noise/split combos) |
| geotransformer | 14 CSVs (all noise/split combos) |
| regtr | 14 CSVs (all noise/split combos) |
| hybridpoint | 14 CSVs (all noise/split combos) |
| pointreggpt | 14 CSVs (all noise/split combos) |

## Two-Phase Design

### Phase 1: Build
```bash
docker run --rm -v /path/to/ros_ws:/home/benchmark/ros_ws fsbench:latest /usr/local/bin/docker-entrypoint-build.sh
```
Does:
1. Colcon build soft20 + fsregistration → `ros_ws/build/`, `ros_ws/install/`

Build artifacts persist on the host. Subsequent builds are fast (cached, ~2 min).

### Phase 2: Benchmark
```bash
docker run --rm -v ... fsbench:latest /usr/local/bin/docker-entrypoint-benchmark.sh soft
```
Does:
1. Source pre-built workspace
2. Create conda environment (if not already created)
3. Build pybind11 module (soft only) or C++ wrappers (regtr only)
4. Fix config paths (→ `/data`)
5. Copy model weights from `/volume/weights`
6. Run benchmark (all noise levels × splits)
7. Auto-merge results
8. Copy results to `/volume/results`

Each method creates only its own conda env on first run.

## Multi-Architecture Support

The Dockerfile works on both x64 and ARM64. Build natively on each machine:
```bash
# On x64 machine
docker build -f .benchmark_docker/Dockerfile -t fsbench:latest .

# On ARM64 machine (e.g., Mac M-series, ARM server)
docker build -f .benchmark_docker/Dockerfile -t fsbench:latest .
```
No `--platform` flag needed — each build targets the host architecture.

## Conda Environments

| Method | Env | Python | PyTorch |
|--------|-----|--------|---------|
| soft | `ml` | 3.12 | >=2.0 |
| fpfh, icp, geotransformer | `geo_env` | 3.10 | 2.0.0 |
| hybridpoint | `hybridpoint_env` | 3.10 | 2.0.0 |
| pointreggpt | `pointreggpt_env` | 3.10 | 2.0.0 |
| regtr | `regtr_env` | 3.10 | 2.0.0 |

## Troubleshooting

### "soft20 not built" error
Run the build phase first:
```bash
docker run --rm -v /path/to/ros_ws:/home/benchmark/ros_ws fsbench:latest /usr/local/bin/docker-entrypoint-build.sh
```

### "Pretrained weights not found" warning
Some ML methods will run without weights (using random initialization). For meaningful results, ensure weights are in the mounted `/volume/weights/` directory.

### Out of memory
Reduce `num_workers` (default 8):
```bash
docker run ... fsbench:latest /usr/local/bin/docker-entrypoint-benchmark.sh soft 2
```

### Build fails on ARM64
Ensure you're using a modern Docker version. The Dockerfile uses `$(uname -m)` for Miniforge download, which handles both architectures.



### Human commands

bash .benchmark_docker/cleanup_before_benchmark.sh
git stash
git pull
git -C src/fsregistration stash
git -C src/fsregistration pull origin main
sudo chmod -R 777 .
bash .benchmark_docker/run_test.sh


nohup bash .benchmark_docker/benchmark_methods/run_fpfh.sh 4 > fpfh.log 2>&1 & # ran on mac
nohup bash .benchmark_docker/benchmark_methods/run_geotransformer.sh 4 > geotransformer.log 2>&1 & # ran on nuc01
nohup bash .benchmark_docker/benchmark_methods/run_hybridpoint.sh 8 > hybridpoint.log 2>&1 & # ran on cubr-admin-02 
nohup bash .benchmark_docker/benchmark_methods/run_icp.sh 12 > icp.log 2>&1 & # ran on mac
nohup bash .benchmark_docker/benchmark_methods/run_pointreggpt.sh 20 > pointreggpt.log 2>&1 & # ran on gpu server
nohup bash .benchmark_docker/benchmark_methods/run_regtr.sh 16 > regtr.log 2>&1 &  # ran on mac
nohup bash .benchmark_docker/benchmark_methods/run_soft.sh 14 --soft-N 32 > soft32.log 2>&1 & # ran on mac
nohup bash .benchmark_docker/benchmark_methods/run_soft.sh 14 --soft-N 64 > soft64.log 2>&1 & # ran on gpu server

nohup bash .benchmark_docker/run_soft_param_bench.sh 12 --range 0 134 > param_bench_m1.log 2>&1 & # ran on mac (combos 0-134)
nohup bash .benchmark_docker/run_soft_param_bench.sh 16 --range 135 269 > param_bench_m2.log 2>&1 & # ran on gpu server (combos 135-269)



nohup bash .benchmark_docker/benchmark_methods/run_soft.sh 12 --soft-N 32 > soft32.log 2>&1 & # ran on nuc01

nohup bash .benchmark_docker/benchmark_methods/run_soft.sh 12 --soft-N 64 --noise-subset low_gauss,high_gauss > soft64_m1.log 2>&1 &   # ran on cubr-admin-02 

nohup bash .benchmark_docker/benchmark_methods/run_soft.sh 10 --soft-N 64 --noise-subset low_salt_pepper,high_salt_pepper > soft64_m2.log 2>&1 & # ran on mac

nohup bash .benchmark_docker/benchmark_methods/run_soft.sh 16 --soft-N 64 --noise-subset None,low,high > soft64_m3.log 2>&1 & # ran on gpu server


nohup bash .benchmark_docker/run_soft_param_bench.sh 12 --range 0 1 > soft64.log 2>&1 & # ran on nuc

nohup bash .benchmark_docker/run_soft_param_bench.sh 12 --range 2 3 > soft64.log 2>&1 & # ran on admin nuc

nohup bash .benchmark_docker/run_soft_param_bench.sh 10 --range 4 5 > soft64.log 2>&1 & # ran on mac

nohup bash .benchmark_docker/run_soft_param_bench.sh 20 --range 6 7 > soft64.log 2>&1 & # ran on GPU server




