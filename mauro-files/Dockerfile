# syntax=docker/dockerfile:1
FROM runpod/pytorch:1.1.0-cu1281-torch280-ubuntu2404

WORKDIR /ComfyUI

COPY . .

RUN ./mauro-files/install-custom-nodes.sh

RUN ./mauro-files/install-pip-requirements.sh
