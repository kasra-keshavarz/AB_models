#!/bin/bash    
# Credit to be mentioned here

# input variables
conf="$1"

# Main message
echo "$(basename $0): Model-agnostic workflow job submission to SLURM" \
    "scheduler on DRA HPC."


#########################
# Temporary file creation
#########################
# Temporary file message
echo "$(basename $0): Creating temporary files..."
# the directory of the script
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# the temp directory used, within $DIR
# omit the -p parameter to create a temporal directory in the default location
WORK_DIR=`mktemp -d -p "$DIR"`

# check if tmp dir was created
if [[ ! "$WORK_DIR" || ! -d "$WORK_DIR" ]]; then
  echo "Could not create temp dir"
  exit 1
fi

# deletes the temp directory
function cleanup {      
  rm -rf "$WORK_DIR"
  echo "Deleted temp working directory $WORK_DIR"
}

# register the cleanup function to be called on the EXIT signal
trap cleanup EXIT


#####################################
# Necessary functions and definitions
#####################################
jqScript="$(dirname $0)/assets/json-funcs.jq"

extract () {
  local func=$1
  local json=$2
  jq -r "$(cat $jqScript) $func" $json;
}

# the `model-agnostic.json` file consists of three main sections
#   1. exec: where the executable paths are defined,
#   2. args: where the arguments to the executables are iterated.
#   3. order: where the order of each section for execution is given

# Register the main keys of $conf: `exec`, `args`, and `order`
mainKeys=("exec" "args" "order")
# Reading the sub-keys from any element of $mainKeys 
mapfile -t subKeys < <(jq -r ".${mainKeys[0]} | keys[]" ${conf})


################################
# Checking requirements of $conf
################################
# check if $conf is a valid JSON file
if jq . $conf >/dev/null 2>$1; then
  :
else
  echo "$(basename $0): ERROR! Input JSON file is not valid"
  exit 1;
fi

# Check the `length` of each key and if unequal, throw an error
initCount=$(extract "count(.${mainKeys[0]})" $conf)
for key in "${mainKeys[@]}"; do
  c=$(extract "count(.${$key})" $conf)
  if [[ $c -ne $initCount ]]; then
    echo "$(basename $0): ERROR! The arguments provided in main arrays"
      "are not equal"
      exit 1;
  fi
done

# Check if the $mainKeys are provided in $conf
mapfile -t derivedKeys< <(jq -r "keys[]" ${conf})
for key in "${derivedKeys[@]}"; do
  if [[ -n "${mainKeys[$key]}" ]]; then
    echo "$(basename $0): ERROR! \`$key\` it not found in $conf"
    exit 1;
  fi
done


#####################
# Running executables 
#####################
# first execute those with `order` value of `-1` (i.e., independant)
# Tip: `indeps` is an array containing "independant" processes
mapfile -t indeps < <(extract "select_independants(.order)" $conf)
for sec in "${indeps[@]}"; do
  # select the executable and related arguments
  executable=$(extract ".exec.${sec}" $conf)
  # check how many sets of `args` are provided for each `section`
  iters=$(extract "count(.args.${indep_sec}[])" $conf)

  # iterate over the `args` provided in each `section`
  for i in $(seq 1 $iters); do
    idx=$(( i - 1 )) # since JSON/jq array indices start from 0
    eval `jq -r ".exec.${sec}"` `extract "parse_args(.args.${sec}[$i])"` \
      >/dev/null 2>&1;
    echo "$(basename $0): Script for ${sec} for the ${i} iteration is"
      "executed"
  done
done

# submitting dependant jobs
 
