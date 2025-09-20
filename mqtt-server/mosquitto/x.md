podman run --net=host -d \
--name mqtt-broker \
--restart=unless-stopped \
-v /mqtt/mosquitto/config:/mosquitto/config:Z \
docker.cnb.cool/bamboo666/docker-images-chrom/eclipse-mosquitto:2.0