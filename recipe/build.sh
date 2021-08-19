# *****************************************************************
# (C) Copyright IBM Corp. 2021. All Rights Reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
# *****************************************************************
#!/bin/bash

set -vex

# Build Tensorflow from source
SCRIPT_DIR=$RECIPE_DIR/../buildscripts

# expand PREFIX in BUILD file - PREFIX is from conda build environment
#sed -i -e "s:\${PREFIX}:${PREFIX}:" tensorflow/core/platform/default/build_config/BUILD

# Pick up additional variables defined from the conda build environment
$SCRIPT_DIR/set_python_path_for_bazelrc.sh $SRC_DIR/keras
if [[ $build_type == "cuda" ]]
then
  # Pick up the CUDA and CUDNN environment
  $SCRIPT_DIR/set_keras_nvidia_bazelrc.sh $SRC_DIR/keras $PY_VER
fi
# Build the bazelrc
$SCRIPT_DIR/set_keras_bazelrc.sh $SRC_DIR/keras

#Clean up old bazel cache to avoid problems building TF
bazel clean --expunge
bazel shutdown

bazel --bazelrc=$SRC_DIR/keras/keras.bazelrc build \
    --config=opt \
    --config=numa \
    --curses=no \
    //keras/tools/pip_package:build_pip_package

# build a whl file
mkdir -p $SRC_DIR/keras_pkg
bazel-bin/keras/tools/pip_package/build_pip_package $SRC_DIR/keras_pkg

# install using pip from the whl file
pip install --no-deps $SRC_DIR/keras_pkg/keras*.whl

echo "PREFIX: $PREFIX"
echo "RECIPE_DIR: $RECIPE_DIR"

# Install the activate / deactivate scripts that set environment variables
mkdir -p "${PREFIX}"/etc/conda/activate.d
mkdir -p "${PREFIX}"/etc/conda/deactivate.d
cp "${RECIPE_DIR}"/../scripts/activate.sh "${PREFIX}"/etc/conda/activate.d/activate-${PKG_NAME}.sh
cp "${RECIPE_DIR}"/../scripts/deactivate.sh "${PREFIX}"/etc/conda/deactivate.d/deactivate-${PKG_NAME}.sh

bazel clean --expunge
bazel shutdown
