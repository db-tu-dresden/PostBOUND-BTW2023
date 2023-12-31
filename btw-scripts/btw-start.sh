#!/bin/bash

ORIG_ROOT=$(pwd)
TARGET_DIR="BTW23-PostBOUND"

# debug switches
export RESET_DATABASES="true"
export QUERY_REPETITIONS=3

echo ".. Starting pipeline on $(date)"

if [ -d $TARGET_DIR ] ; then
    echo ".. Base environment exists"
    cd $TARGET_DIR
    git pull --recurse-submodules=yes origin btw23-reproducibility
else
    echo ".. Setting up environment on $(date)"
    echo ".. Target directory is $TARGET_DIR"
    git clone --recurse-submodules --branch btw23-reproducibility --depth 1 https://github.com/rbergm/PostBOUND.git temp
    mv temp/* $TARGET_DIR
    mv temp/.git* $TARGET_DIR
    rm -r temp
fi

echo ".. Preparing directory structure on $(date)"
ROOT=$ORIG_ROOT/$TARGET_DIR
cd $ROOT
cp $ORIG_ROOT/btw-exp*.sh .
cp $ORIG_ROOT/btw-setup.R .
cp $ORIG_ROOT/btw-tex.sh .

echo ".. Setting up Python venv on $(date)"
python3 -m venv postbound-venv
. postbound-venv/bin/activate
pip install --progress-bar off wheel
pip install --progress-bar off -r requirements.txt

echo ".. Setting up R environment on $(date)"
Rscript --vanilla btw-setup.R

cd $ROOT/postgres
echo ".. Setting up Postgres v14 on $(date)"
./postgres-setup.sh --stop
./postgres-psycopg-setup.sh job imdb
./postgres-psycopg-setup.sh stack stack_dummy
./postgres-psycopg-setup.sh tpch tpch
mv .psycopg_connection_* $ROOT/ues

cd $ROOT/postgres_12_4
echo ".. Setting up Postgres v12 on $(date)"
./postgres-setup.sh --stop

cd $ROOT
echo ".. Starting Experiment 01 on $(date) :: Figure 01 - UES overestimation"
./btw-exp01.sh

cd $ROOT
echo ".. Starting Experiment 02 on $(date) :: Table 01 - Benchmark runtimes"
./btw-exp02.sh

cd $ROOT
echo ".. Starting Experiment 03 on $(date) :: Figure 07 - Subquery speedup"
./btw-exp03.sh

cd $ROOT
echo ".. Starting Experiment 04 on $(date) :: Figure 08 - top-k influence"
./btw-exp04.sh

cd $ROOT
echo ".. Starting Experiment 05 on $(date) :: Figure 09 - IdxNLJ operators"
./btw-exp05.sh

cd $ROOT/ues
echo ".. Generating result figures on $(date)"
python3 postbound-eval.py
Rscript --vanilla evaluation/plots-presentation.R

cd $ROOT
echo ".. Creating final paper on $(date)"
./btw-tex.sh

cd $ORIG_ROOT
echo ".. Done on $(date)"
