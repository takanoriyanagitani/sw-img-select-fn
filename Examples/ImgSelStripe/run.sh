#!/bin/sh

export ENV_O_IMG_NAME=./sample.d/out.png

mkdir -p ./sample.d

./ImgSelStripe

file "${ENV_O_IMG_NAME}"
