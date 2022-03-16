#!/bin/bash
set -e -u

rm -rf .build Build

CONFIG=Release
cmake -S . -B Build/${CONFIG} -DCMAKE_BUILD_TYPE=${CONFIG}
cmake --build Build/${CONFIG} --target clean
cmake --build Build/${CONFIG} --target DMCLBMMetal

rm -f movie.mov
time .build/${CONFIG}/DMCLBMMetalSim
open movie.mov
