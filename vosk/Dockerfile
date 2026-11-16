# Vosk with the small French and English models, for the call's captions.
# The large models (alphacep/kaldi-fr, kaldi-en) take 3+ GB of RAM each: too
# much next to Jitsi on a 6 GB server. These load in ~300 MB each, at some
# cost in accuracy. One image, one container per language (docker-compose.yml
# starts the server on the model it names): a Vosk server speaks one language.
# The server image and both models are pinned (digest, sha256).
FROM alphacep/kaldi-vosk-server@sha256:381024347b954835c9c20adea2041377e7b55f50d4c5887eb42101bbf6e750a1

ARG MODEL_FR=vosk-model-small-fr-0.22
ARG MODEL_FR_SHA256=cabf6180e177eb9b3a9a9d43a437bd5e549f3a7d09525e5d69a3fed787be12ad
ARG MODEL_EN=vosk-model-small-en-us-0.15
ARG MODEL_EN_SHA256=30f26242c4eb449f948e42cb302dd7a686cb29a3423a8367f99ff41780942498

RUN cd /opt \
  && wget -q "https://alphacephei.com/vosk/models/${MODEL_FR}.zip" \
  && echo "${MODEL_FR_SHA256}  ${MODEL_FR}.zip" | sha256sum -c - \
  && unzip -q "${MODEL_FR}.zip" \
  && mv "${MODEL_FR}" /opt/vosk-model \
  && rm "${MODEL_FR}.zip"

RUN cd /opt \
  && wget -q "https://alphacephei.com/vosk/models/${MODEL_EN}.zip" \
  && echo "${MODEL_EN_SHA256}  ${MODEL_EN}.zip" | sha256sum -c - \
  && unzip -q "${MODEL_EN}.zip" \
  && mv "${MODEL_EN}" /opt/vosk-model-en \
  && rm "${MODEL_EN}.zip"

EXPOSE 2700
WORKDIR /opt/vosk-server/websocket
# French unless the container names another model (vosk-en in docker-compose.yml).
CMD ["python3", "./asr_server.py", "/opt/vosk-model"]
