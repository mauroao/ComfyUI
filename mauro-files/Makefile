TAG = mauroao/runpod-comfy:0.1.14

docker-build:
	docker build -t $(TAG) -f Dockerfile ..

docker-push:
	docker push docker.io/$(TAG)

docker-run:
	docker run --rm -it --gpus all --shm-size=8g $(TAG) /bin/bash
