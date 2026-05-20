# fsregistration Benchmark Docker

Docker-based benchmarking for 3D registration methods. Two-phase design: build the workspace once, then run benchmarks on each machine.

## Quick Start

```bash
# 1. Build image (~15 min)
cd /path/to/volumeROS
docker build -f .benchmark_docker/Dockerfile -t fsbench:latest .

# 2. Build workspace (first time only, ~10 min)
docker run --rm -v /path/to/volumeROS/ros_ws:/home/benchmark/ros_ws fsbench:latest /usr/local/bin/docker-entrypoint-build.sh

# 3. Run a benchmark
docker run --rm \
  -v /path/to/volumeROS/ros_ws:/home/benchmark/ros_ws \
  -v /path/to/volumeROS/dataFolder:/data:ro \
  -v ./benchmark_results:/volume/results \
  fsbench:latest /usr/local/bin/docker-entrypoint-benchmark.sh soft 8
```

## Setup on Each Server

### 1. Clone the repo
```bash
git clone <fsregistration-repo-url>
cd volumeROS
```

### 2. Build the image
```bash
docker build -f .benchmark_docker/Dockerfile -t fsbench:latest .
```
**Build time:** ~15 minutes (OpenCV 10min, PCL 5min)

### 3. Build the workspace (first time only)
```bash
docker run --rm -v /path/to/volumeROS/ros_ws:/home/benchmark/ros_ws fsbench:latest /usr/local/bin/docker-entrypoint-build.sh
```
This compiles soft20 + fsregistration with colcon, creates conda environments, builds pybind11, and compiles C++ wrappers. Build artifacts persist in `ros_ws/build/` and `ros_ws/install/`.

**Build time:** ~10 minutes first run, ~2 minutes on subsequent runs (cached).

### 4. Prepare data directory
```
/path/to/volumeROS/dataFolder/models/predator/data/indoor/  ← 3DMatch .pth point cloud files
```

### 5. Prepare weights directory
Create a `weights/` directory alongside `dataFolder/`:
```
/path/to/volumeROS/weights/
├── regtr-3dmatch-model-best.pth      ← RegTR model weights
├── hybridpoint-3dmatch.tar           ← HybridPoint model weights
└── predator-indoor.pth               ← Predator model weights
```
GeoTransformer weights (`geotransformer-3dmatch.pth.tar`) are already in the repo.

**Weight download links:**
- **RegTR:** https://github.com/yewzijian/RegTR/releases
- **HybridPoint:** From HybridPoint repo
- **Predator:** From Predator repo (https://github.com/zhanwenchen/Predator)

## Running Benchmarks

### Command format
```bash
docker run --rm \
  -v /path/to/volumeROS/ros_ws:/home/benchmark/ros_ws \
  -v /path/to/volumeROS/dataFolder:/data:ro \
  -v /path/to/volumeROS/weights:/volume/weights:ro \
  -v ./benchmark_results:/volume/results \
  fsbench:latest /usr/local/bin/docker-entrypoint-benchmark.sh <method> [num_workers]
```

### Method assignment (3 machines, 7 methods)

**Machine 1:**
```bash
docker run --rm \
  -v /path/to/volumeROS/ros_ws:/home/benchmark/ros_ws \
  -v /path/to/volumeROS/dataFolder:/data:ro \
  -v /path/to/volumeROS/weights:/volume/weights:ro \
  -v ./results:/volume/results \
  fsbench:latest /usr/local/bin/docker-entrypoint-benchmark.sh soft
```

**Machine 2:**
```bash
docker run --rm \
  -v /path/to/volumeROS/ros_ws:/home/benchmark/ros_ws \
  -v /path/to/volumeROS/dataFolder:/data:ro \
  -v /path/to/volumeROS/weights:/volume/weights:ro \
  -v ./results:/volume/results \
  fsbench:latest /usr/local/bin/docker-entrypoint-benchmark.sh fpfh

docker run --rm \
  -v /path/to/volumeROS/ros_ws:/home/benchmark/ros_ws \
  -v /path/to/volumeROS/dataFolder:/data:ro \
  -v /path/to/volumeROS/weights:/volume/weights:ro \
  -v ./results:/volume/results \
  fsbench:latest /usr/local/bin/docker-entrypoint-benchmark.sh icp
```

**Machine 3:**
```bash
docker run --rm \
  -v /path/to/volumeROS/ros_ws:/home/benchmark/ros_ws \
  -v /path/to/volumeROS/dataFolder:/data:ro \
  -v /path/to/volumeROS/weights:/volume/weights:ro \
  -v ./results:/volume/results \
  fsbench:latest /usr/local/bin/docker-entrypoint-benchmark.sh geotransformer

docker run --rm \
  -v /path/to/volumeROS/ros_ws:/home/benchmark/ros_ws \
  -v /path/to/volumeROS/dataFolder:/data:ro \
  -v /path/to/volumeROS/weights:/volume/weights:ro \
  -v ./results:/volume/results \
  fsbench:latest /usr/local/bin/docker-entrypoint-benchmark.sh regtr

docker run --rm \
  -v /path/to/volumeROS/ros_ws:/home/benchmark/ros_ws \
  -v /path/to/volumeROS/dataFolder:/data:ro \
  -v /path/to/volumeROS/weights:/volume/weights:ro \
  -v ./results:/volume/results \
  fsbench:latest /usr/local/bin/docker-entrypoint-benchmark.sh hybridpoint

docker run --rm \
  -v /path/to/volumeROS/ros_ws:/home/benchmark/ros_ws \
  -v /path/to/volumeROS/dataFolder:/data:ro \
  -v /path/to/volumeROS/weights:/volume/weights:ro \
  -v ./results:/volume/results \
  fsbench:latest /usr/local/bin/docker-entrypoint-benchmark.sh pointreggpt
```

## Output Files

Each method produces CSV files in `./benchmark_results/<method>/`:

| Method | Output CSVs |
|--------|------------|
| soft | `outfile_soft_None_val.csv`, `outfile_soft_None_train.csv`, `outfile_soft_low_val.csv`, `outfile_soft_low_train.csv`, `outfile_soft_high_val.csv`, `outfile_soft_high_train.csv` |
| fpfh | `outfile_fpfh_low_train.csv`, `outfile_fpfh_high_train.csv` |
| icp | 6 CSVs (all noise/split combos) |
| geotransformer | 6 CSVs (all noise/split combos) |
| regtr | 6 CSVs (all noise/split combos) |
| hybridpoint | `outfile_hybridpoint_high_train.csv` |
| pointreggpt | `outfile_pointreggpt_high_train.csv` |

## Two-Phase Design

### Phase 1: Build
```bash
docker run --rm -v /path/to/volumeROS/ros_ws:/home/benchmark/ros_ws fsbench:latest /usr/local/bin/docker-entrypoint-build.sh
```
Does:
1. Colcon build soft20 + fsregistration → `ros_ws/build/`, `ros_ws/install/`
2. Create 5 conda environments (ml, geo_env, hybridpoint_env, pointreggpt_env, regtr_env)
3. Build pybind11 module for SOFT
4. Compile C++ wrappers for RegTR

Build artifacts persist on the host. Subsequent builds are fast (cached).

### Phase 2: Benchmark
```bash
docker run --rm -v ... fsbench:latest /usr/local/bin/docker-entrypoint-benchmark.sh soft
```
Does:
1. Source pre-built workspace
2. Activate correct conda environment
3. Fix config paths (→ `/data`)
4. Copy model weights from `/volume/weights`
5. Run benchmark (all noise levels × splits)
6. Auto-merge results
7. Copy results to `/volume/results`

No compilation needed — uses pre-built artifacts from Phase 1.

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
docker run --rm -v /path/to/volumeROS/ros_ws:/home/benchmark/ros_ws fsbench:latest /usr/local/bin/docker-entrypoint-build.sh
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
