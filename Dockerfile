FROM google/cloud-sdk

COPY mygcloud /root/.config/gcloud
COPY docker-entrypoint.sh /docker-entrypoint.sh
COPY cmds /cmds
COPY k8s /k8s

RUN python3 -m pip install pyyaml
RUN apt-get update && apt-get install bsdmainutils
WORKDIR /cmds
ENTRYPOINT ["/docker-entrypoint.sh"]