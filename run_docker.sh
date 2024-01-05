#!/usr/bin/env bash

docker build -t mtkhawaja/dev-env:latest . && docker run -it --rm mtkhawaja/dev-env:latest
