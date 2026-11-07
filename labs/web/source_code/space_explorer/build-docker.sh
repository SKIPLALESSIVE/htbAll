#!/bin/bash

docker build -t web_space_explorer_mp -f Dockerfile .
docker run -d -p 8080:8080 --name web_space_explorer_mp web_space_explorer_mp
