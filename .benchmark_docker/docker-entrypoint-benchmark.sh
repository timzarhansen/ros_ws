#!/usr/bin/env bash
set -eo pipefail

METHOD="${1:-}"
NUM_WORKERS="${2:-8}"

if [ -z "$METHOD" ]; then
  echo "Usage: $0 <method> [num_workers]"
  echo "Methods: soft fpfh icp geotransformer regtr hybridpoint pointreggpt"
  exit 1
fi

# === Verify build artifacts exist ===
if [ ! -d /home/benchmark/ros_ws/install/soft20 ]; then
  echo "ERROR: soft20 not built. Run 'docker-entrypoint-build.sh' first."
  exit 1
fi

# === 1. Source ROS2 + workspace ===
. /opt/ros/humble/setup.bash
. /home/benchmark/ros_ws/install/setup.bash

# === 2. Activate correct conda env ===
source /opt/miniforge3/etc/profile.d/conda.sh
case "$METHOD" in
  soft)            conda activate ml ;;
  fpfh|icp|geotransformer) conda activate geo_env ;;
  hybridpoint)     conda activate hybridpoint_env ;;
  pointreggpt)     conda activate pointreggpt_env ;;
  regtr)           conda activate regtr_env ;;
  *) echo "Unknown method: $METHOD"; exit 1 ;;
esac

cd /home/benchmark/ros_ws/src/fsregistration/pythonScripts/matchingProfiling3D

# === 3. Fix config paths ===
sed -i 's|/home/tim-external/dataFolder/3dmatch|/data|g' configFiles/predatorNothing.yaml
sed -i 's|/Users/timhansen/Documents/dataFolder/3dmatch|/data|g' configFiles/predatorNothing.yaml

# === 4. Copy weights from /volume/weights ===
if [ -f /volume/weights/regtr-3dmatch-model-best.pth ]; then
  mkdir -p /home/benchmark/ros_ws/src/fsregistration/ml_registration/regtr/trained_models/3dmatch/ckpt/
  cp /volume/weights/regtr-3dmatch-model-best.pth \
    /home/benchmark/ros_ws/src/fsregistration/ml_registration/regtr/trained_models/3dmatch/ckpt/model-best.pth
  echo "Copied RegTR weights"
fi

if [ -f /volume/weights/hybridpoint-3dmatch.tar ]; then
  mkdir -p /home/benchmark/ros_ws/src/fsregistration/ml_registration/hybridpoint/weights_for_hybrid/
  cp /volume/weights/hybridpoint-3dmatch.tar \
    /home/benchmark/ros_ws/src/fsregistration/ml_registration/hybridpoint/weights_for_hybrid/3dmatch.tar
  echo "Copied HybridPoint weights"
fi

if [ -f /volume/weights/predator-indoor.pth ]; then
  mkdir -p /data/models/predator/data/weights/
  cp /volume/weights/predator-indoor.pth /data/models/predator/data/weights/indoor.pth
  echo "Copied Predator weights"
fi

# === 5. Run benchmark ===
case "$METHOD" in
  soft)
    # No runSoft_batch.sh exists, call run_parallel_batches.py directly
    for noise in None low high; do
      for split in val train; do
        TOTAL_SAMPLES=$( [ "$split" = "val" ] && echo 1331 || echo 20642 )
        echo ""
        echo "=============================================="
        echo "SOFT: $noise / $split"
        echo "=============================================="
        python3 bashScripts/run_parallel_batches.py \
          --config configFiles/predatorNothing.yaml \
          --noise-level "$noise" \
          --data-type "$split" \
          --total-samples "$TOTAL_SAMPLES" \
          --batch-size 100 \
          --num-workers "$NUM_WORKERS" \
          --model-type soft \
          --soft-N 128 \
          --soft-use-clahe 0 \
          --soft-r-min 16 \
          --soft-r-max 48 \
          --soft-level-rotation 0.001 \
          --soft-level-translation 0.001 \
          --soft-normalization 2
        python3 bashScripts/merge_and_deduplicate.py \
          --noise-level "$noise" \
          --data-type "$split" \
          --model-type soft
      done
    done
    ;;

  fpfh|icp|geotransformer|regtr|hybridpoint|pointreggpt)
    # Use existing batch scripts
    case "$METHOD" in
      fpfh)            SCRIPT="bashScripts/runFPFH_batch.sh" ;;
      icp)             SCRIPT="bashScripts/runICP_batch.sh" ;;
      geotransformer)  SCRIPT="bashScripts/runGeoTransformer_batch.sh" ;;
      regtr)           SCRIPT="bashScripts/runRegTR_batch.sh" ;;
      hybridpoint)     SCRIPT="bashScripts/runHybridPoint_batch.sh" ;;
      pointreggpt)     SCRIPT="bashScripts/runPointRegGPT_batch.sh" ;;
    esac
    # Fix config filename to use our fixed config
    sed -i 's|predatorNothingMac.yaml|predatorNothing.yaml|g' "$SCRIPT"
    # Fix worker count
    sed -i "s|NUM_WORKERS=.*|NUM_WORKERS=${NUM_WORKERS}|g" "$SCRIPT"
    bash "$SCRIPT"
    ;;
esac

# === 6. Copy results to volume mount ===
if [ -d "outputFiles/$METHOD" ]; then
  mkdir -p /volume/results/"$METHOD"
  cp -r outputFiles/"$METHOD"/* /volume/results/"$METHOD"/ 2>/dev/null || true
fi

echo ""
echo "=============================================="
echo "=== DONE: $METHOD ==="
echo "=============================================="
ls -la /volume/results/"$METHOD"/outfile_*.csv 2>/dev/null || echo "(no output CSV files)"
