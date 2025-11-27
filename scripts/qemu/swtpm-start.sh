#!/bin/bash

: ${TPM_STATE_DIR=tpm-state}

if [ $(echo $TPM_STATE_DIR/tpm-sock | wc -c) -gt 107 ] ; then
        echo -e "\x1b[31mThe TPM path is too long. Please run again, with a different TPM_STATE_DIR\x1b[0m"
	exit 1
fi


mkdir -p $TPM_STATE_DIR

swtpm socket \
    --tpm2 \
    --tpmstate dir=${TPM_STATE_DIR} \
    --ctrl type=unixio,path=${TPM_STATE_DIR}/swtpm-sock \
    --flags not-need-init \
    --log level=20 \
    -d

echo "TPM Deamon started. State: $TPM_STATE_DIR: $(ls $TPM_STATE_DIR)"
echo
exit 0
# exit statement to allow the following "documentation"
kernel configs required to make this work::
 TCG_TPM n -> y
+CRYPTO_LIB_AESCFB y
+HW_RANDOM_TPM y
+TCG_ATMEL n
+TCG_CRB y
+TCG_INFINEON n
+TCG_NSC n
+TCG_TIS y
+TCG_TIS_CORE y
+TCG_TIS_I2C y
+TCG_TIS_I2C_ATMEL n
+TCG_TIS_I2C_CR50 n
+TCG_TIS_I2C_INFINEON n
+TCG_TIS_I2C_NUVOTON n
+TCG_TIS_ST33ZP24_I2C n
+TCG_TPM2_HMAC y
+TCG_VTPM_PROXY n

