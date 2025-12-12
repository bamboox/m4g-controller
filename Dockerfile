# Build stage
ARG BASE_IMAGE=docker.cnb.cool/bamboo666/docker-images-chrom/gguf-base:latest
FROM ${BASE_IMAGE} AS builder

WORKDIR /app

# Build arguments
ARG HF_MODEL_ID
ARG HF_TOKEN=""
ARG QUANTIZATION="f16"

# Check if HF_MODEL_ID is set
RUN if [ -z "$HF_MODEL_ID" ]; then echo "HF_MODEL_ID is required"; exit 1; fi

# Download model
# We use huggingface-cli to download the model to a local directory
RUN hf download ${HF_MODEL_ID} --local-dir ./model_raw  --token "${HF_TOKEN}"

# Convert to GGUF
# Note: The script name might vary slightly depending on llama.cpp version, but convert-hf-to-gguf.py is standard now.
# We output to a fixed name 'model.gguf' for easier copying.
RUN python3 llama.cpp/convert_hf_to_gguf.py ./model_raw --outfile model.gguf --outtype ${QUANTIZATION}

# Final stage
FROM alpine:latest

WORKDIR /data

# Copy the converted model
COPY --from=builder /app/model.gguf /data/model.gguf

# Default command to list the file, just to show it's there
CMD ["ls", "-lh", "/data/model.gguf"]
