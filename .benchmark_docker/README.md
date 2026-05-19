# fsregistration Benchmark Docker

Docker-based benchmarking for 3D registration methods. Each container runs one complete benchmark (all samples, all noise levels, all splits) and produces final CSV output files.

## Quick Start

```bash
# Build (~35 min)
cd /path/to/volumeROS
docker build -f .benchmark_docker/Dockerfile -t fsbench:latest .

# Run a benchmark
docker run --rm \
  -v /shared/data:/data:ro \
  -v /shared/weights:/volume/weights:ro \
  -v ./benchmark_results:/volume/results \
  fsbench:latest soft 8
```

## Setup on Each Server

### 1. Clone fsregistration repo
```bash
git clone <fsregistration-repo-url>
cd volumeROS
```

### 2. Build the image
```bash
docker build -f .benchmark_docker/Dockerfile -t fsbench:latest .
```
**Build time:** ~35 minutes (OpenCV 15min, PCL 10min, rest 10min)

### 3. Prepare data directory
```
/shared/data/models/predator/data/indoor/  ← 3DMatch .pth point cloud files
```

### 4. Prepare weights directory
```
/shared/weights/
├── regtr-3dmatch-model-best.pth      ← RegTR model weights
├── hybridpoint-3dmatch.tar           ← HybridPoint model weights
└── predator-indoor.pth               ← Predator model weights
```
GeoTransformer weights (`geotransformer-3dmatch.pth.tar`) are already included in the repo.

**Weight download links:**
- **RegTR:** https://github.com/yewzijian/RegTR/releases
- **HybridPoint:** From HybridPoint repo (contact author or check their releases)
- **Predator:** From Predator repo (https://github.com/zhanwenchen/Predator)

## Running Benchmarks

### Command format
```bash
docker run --rm \
  -v /path/to/data:/data:ro \
  -v /path/to/weights:/volume/weights:ro \
  -v ./benchmark_results:/volume/results \
  fsbench:latest <method> [num_workers]
```

### Method assignment (3 machines, 7 methods)

**Machine 1:**
```bash
docker run --rm -v /data:/data:ro -v /weights:/volume/weights:ro -v ./results:/volume/results fsbench:latest soft
```

**Machine 2:**
```bash
docker run --rm -v /data:/data:ro -v /weights:/volume/weights:ro -v ./results:/volume/results fsbench:latest fpfh
docker run --rm -v /data:/data:ro -v /weights:/volume/weights:ro -v ./results:/volume/results fsbench:latest icp
```

**Machine 3:**
```bash
docker run --rm -v /data:/data:ro -v /weights:/volume/weights:ro -v ./results:/volume/results fsbench:latest geotransformer
docker run --rm -v /data:/data:ro -v /weights:/volume/weights:ro -v ./results:/volume/results fsbench:latest regtr
docker run --rm -v /data:/data:ro -v /weights:/volume/weights:ro -v ./results:/volume/results fsbench:latest hybridpoint
docker run --rm -v /data:/data:ro -v /weights:/volume/weights:ro -v ./results:/volume/results fsbench:latest pointreggpt
```

## Output Files

Each method produces CSV files in `./benchmark_results/<method>/`:

| Method | Output CSVs |
|--------|------------|
| soft | `outfile_soft_None_val.csv`, `outfile_soft_None_train.csv`, `outfile_soft_low_val.csv`, `outfile_soft_low_train.csv`, `outfile_soft_high_val.csv`, `outfile_soft_high_train.csv` |
| fpfh | `outfile_fpfh_low_train.csv`, `outfile_fpfh_high_train.csv` |
| icp | `outfile_icp_None_val.csv`, `outfile_icp_None_train.csv`, `outfile_icp_low_val.csv`, `outfile_icp_low_train.csv`, `outfile_icp_high_val.csv`, `outfile_icp_high_train.csv` |
| geotransformer | 6 CSVs (all noise/split combos) |
| regtr | 6 CSVs (all noise/split combos) |
| hybridpoint | `outfile_hybridpoint_high_train.csv` |
| pointreggpt | `outfile_pointreggpt_high_train.csv` |

## Multi-Architecture Support

The Dockerfile works on both x64 and ARM64. Build natively on each machine:
```bash
# On x64 machine
docker build -f .benchmark_docker/Dockerfile -t fsbench:latest .

# On ARM64 machine (e.g., Mac M-series, ARM server)
docker build -f .benchmark_docker/Dockerfile -t fsbench:latest .
```
No `--platform` flag needed — each build targets the host architecture automatically.

## Conda Environments

Each method uses a dedicated conda environment:

| Method | Env | Python | PyTorch |
|--------|-----|--------|---------|
| soft | `ml` | 3.12 | >=2.0 |
| fpfh, icp, geotransformer | `geo_env` | 3.10 | 2.0.0 |
| hybridpoint | `hybridpoint_env` | 3.10 | 2.0.0 |
| pointreggpt | `pointreggpt_env` | 3.10 | 2.0.0 |
| regtr | `regtr_env` | 3.10 | 2.0.0 |

## Troubleshooting

### "Pretrained weights not found" warning
Some ML methods will run without weights (using random initialization). For meaningful results, ensure weights are in `/shared/weights/` and mounted to `/volume/weights`.

### Out of memory
Reduce `num_workers` (default 8):
```bash
docker run ... fsbench:latest soft 2
```

### Build fails on ARM64
Ensure you're using a modern Docker version that supports multi-arch builds. The Dockerfile uses `$(uname -m)` for Miniforge download, which handles both architectures.
