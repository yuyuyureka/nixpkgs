preCheckHooks+=('garageStart')
postCheckHooks+=('garageStop')


garageStart() {
  if [[ "${GARAGE_DATA:-}" == "" ]]; then
    GARAGE_DATA="$NIX_BUILD_TOP/garage"
  fi
  export GARAGE_DATA

  if [[ "${AWS_DEFAULT_REGION:-}" == "" ]]; then
    AWS_DEFAULT_REGION="garage"
  fi
  export AWS_DEFAULT_REGION

  if [[ "${AWS_S3_ENDPOINT_URL:-}" == "" ]]; then
    AWS_S3_ENDPOINT_URL="http://[::1]:9000"
  fi
  export AWS_S3_ENDPOINT_URL

  if [[ "${AWS_ACCESS_KEY_ID:-}" == "" ]]; then
    AWS_ACCESS_KEY_ID="GK000000000000000000000000"
  fi
  export AWS_ACCESS_KEY_ID

  if [[ "${AWS_SECRET_ACCESS_KEY:-}" == "" ]]; then
    AWS_SECRET_ACCESS_KEY="0000000000000000000000000000000000000000000000000000000000000000"
  fi
  export AWS_SECRET_ACCESS_KEY

  if [[ "${AWS_S3_UPLOAD_BUCKET_NAME:-}" == "" ]]; then
    AWS_S3_UPLOAD_BUCKET_NAME="testbucket"
  fi
  export AWS_S3_UPLOAD_BUCKET_NAME

  if [[ "${garageTestBuckets:-}" == "" ]]; then
    garageTestBuckets=("testbucket")
  fi

  if ! type garage >/dev/null; then
    echo >&2 'garage not found. Did you add garage to the nativeCheckInputs?'
    false
  fi

  GARAGE_RPC_BIND="[::1]:3901"
  GARAGE_RPC_ADDR="$GARAGE_RPC_BIND"
  GARAGE_RPC_SECRET=0000000000000000000000000000000000000000000000000000000000000000
  mkdir -p "$GARAGE_DATA"
  cat > "$GARAGE_DATA/garage.toml" <<EOF
metadata_dir = "$GARAGE_DATA/metadata"
data_dir = "$GARAGE_DATA/data"
db_engine = "sqlite"

replication_factor = 1

rpc_bind_addr = "$GARAGE_RPC_BIND"
rpc_public_addr = "$GARAGE_RPC_ADDR"
rpc_secret = "$GARAGE_RPC_SECRET"

[s3_api]
s3_region = "$AWS_DEFAULT_REGION"
api_bind_addr = "${AWS_S3_ENDPOINT_URL#"http://"}"
EOF

  echo "$garageExtraSettings" >>"$GARAGE_DATA/garage.toml"

  echo 'starting garage'
  RUST_LOG="info,garage_api_common::generic_server=warn" garage -c "$GARAGE_DATA/garage.toml" server &
  GARAGE_PID=$!

  while ! garage -c "$GARAGE_DATA/garage.toml" status; do
    echo waiting for garage to be ready
    sleep 1
  done

  GARAGE_NODE_ID="$(head -c 8 "$GARAGE_DATA/metadata/node_key.pub" | od -An -vtx1 | tr -d ' \n')"

  garage -c "$GARAGE_DATA/garage.toml" layout assign -c 1T -z "test" "$GARAGE_NODE_ID"
  garage -c "$GARAGE_DATA/garage.toml" layout apply --version 1

  echo 'setting up garage'
  garage -c "$GARAGE_DATA/garage.toml" key import "$AWS_ACCESS_KEY_ID" "$AWS_SECRET_ACCESS_KEY" -n testkey --yes
  for bucket in "${garageTestBuckets[@]}"; do
    echo "creating bucket $bucket"
    garage -c "$GARAGE_DATA/garage.toml" bucket create "$bucket"
    garage -c "$GARAGE_DATA/garage.toml" bucket allow --read --write --owner "$bucket" --key testkey
  done

  runHook garageTestSetupPost

}

garageStop() {
  echo 'stopping garage'
  kill $GARAGE_PID
}
