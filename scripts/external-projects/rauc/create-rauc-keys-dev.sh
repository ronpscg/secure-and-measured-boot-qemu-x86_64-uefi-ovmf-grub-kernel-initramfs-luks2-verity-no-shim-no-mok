cd $(dirname ${BASH_SOURCE[0]})
pwd
set -euo pipefail
# The script is obviously dev, and the paths are like this as it is expected to be run in your docker environment
# where the paths match the conventions of the other scripts
: ${TARGET_KEYS_DIR=$HOME/pscg/customers/build-stuff/rauc/keys}
mkdir -p $TARGET_KEYS_DIR
./create-keys-impl.sh
cp keys/example/example-ca/ca.cert.pem $TARGET_KEYS_DIR
cp keys/example/example-ca/development-1.cert.pem $TARGET_KEYS_DIR
cp keys/example/example-ca/private/development-1.key.pem $TARGET_KEYS_DIR

echo -e "\e[32mHooray, your keys are in $TARGET_KEYS_DIR\e[0m"
