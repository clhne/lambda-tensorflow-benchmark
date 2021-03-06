#!/bin/bash -e
SCRIPT_DIR="/home/${USER}/benchmarks/scripts/tf_cnn_benchmarks"


CPU_NAME="$(lscpu | grep "Model name:" | sed -r 's/Model name:\s{1,}//g' | awk '{ print $4 }')";
if [ $CPU_NAME = "CPU" ]; then
  # CPU can show up at different locations
  CPU_NAME="$(lscpu | grep "Model name:" | sed -r 's/Model name:\s{1,}//g' | awk '{ print $3 }')";
fi

GPU_NAME=1080TI

CONFIG_NAME="${CPU_NAME}-${GPU_NAME}"
echo $CONFIG_NAME


DATA_DIR="/home/${USER}/data/imagenet_mini"
LOG_DIR="/home/${USER}/imagenet_benchmark_logs/${CONFIG_NAME}"

ITERATIONS=10
NUM_BATCHES=100

MODELS=(
  resnet50
  resnet152
  inception3
  inception4
  vgg16
  alexnet
  ssd300
)

VARIABLE_UPDATE=(
  parameter_server
)

DATA_MODE=(
  syn
  # real
)

declare -A BATCH_SIZES=(
  [resnet50]=64
  [resnet101]=64
  [resnet152]=32
  [inception3]=64
  [inception4]=16
  [vgg16]=64
  [alexnet]=512
  [ssd300]=16
)

declare -A DATASET_NAMES=(
  [resnet50]=imagenet
  [resnet101]=imagenet
  [resnet152]=imagenet
  [inception3]=imagenet
  [inception4]=imagenet
  [vgg16]=imagenet
  [alexnet]=imagenet
  [ssd300]=coco  
)

MIN_NUM_GPU=1
MAX_NUM_GPU=1

run_benchmark() {

  local model="$1"
  local batch_size=$2
  local config_name=$3
  local num_gpus=$4
  local iter=$5
  local data_mode=$6
  local update_mode=$7
  local distortions=$8
  local dataset_name=$9

  pushd "$SCRIPT_DIR" &> /dev/null
  local args=()
  local output="${LOG_DIR}/${model}-${data_mode}-${variable_update}"

  args+=("--optimizer=sgd")
  args+=("--model=$model")
  args+=("--num_gpus=$num_gpus")
  args+=("--batch_size=$batch_size")
  args+=("--variable_update=$variable_update")
  args+=("--distortions=$distortions")
  args+=("--num_batches=$NUM_BATCHES")
  args+=("--data_name=$dataset_name")

  if [ $data_mode = real ]; then
    args+=("--data_dir=$DATA_DIR")
  fi
  if $distortions; then
    output+="-distortions"
  fi
  output+="-${num_gpus}gpus-${batch_size}-${iter}.log"

  mkdir -p "${LOG_DIR}" || true
  
  # echo $output
  echo ${args[@]}
  python3 tf_cnn_benchmarks.py "${args[@]}" |& tee "$output"
  popd &> /dev/null
}

run_benchmark_all() {
  local data_mode="$1" 
  local variable_update="$2"
  local distortions="$3"

  for model in "${MODELS[@]}"; do
    local batch_size=${BATCH_SIZES[$model]}
    local dataset_name=${DATASET_NAMES[$model]}
    for num_gpu in `seq ${MAX_NUM_GPU} -1 ${MIN_NUM_GPU}`; do 
      for iter in $(seq 1 $ITERATIONS); do
        run_benchmark "$model" $batch_size $CONFIG_NAME $num_gpu $iter $data_mode $variable_update $distortions $dataset_name
      done
    done
  done  
}

main() {
  local data_mode variable_update distortion_mode model num_gpu iter benchmark_name distortions
  local cpu_line table_line

  for data_mode in "${DATA_MODE[@]}"; do
    for variable_update in "${VARIABLE_UPDATE[@]}"; do
      for distortions in true false; do
        if [ $data_mode = syn ] && $distortions ; then
          # skip distortion for synthetic data
          :
        else
          run_benchmark_all $data_mode $variable_update $distortions
        fi
      done
    done
  done

}

main "$@"
