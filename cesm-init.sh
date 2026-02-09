#!/bin/bash

export CIME_CONFIG_DIR="${HOME}/.cime"
export CASE_ROOT="${HOME}/cesm-cases"
export USER=$(whoami)

# Create ~/.cime with machine configs if not present
if [ ! -d "${CIME_CONFIG_DIR}" ]; then
    echo "Initializing CIME configuration in ${CIME_CONFIG_DIR}..."
    mkdir -p "${CIME_CONFIG_DIR}"
    cp /opt/cime-confg/config_machines.xml "${CIME_CONFIG_DIR}/"
    cp /opt/cime-confg/config_compilers.xml "${CIME_CONFIG_DIR}/"
    cp /opt/cime-confg/config_batch.xml "${CIME_CONFIG_DIR}/"
    echo "CIME configuration installed."
else
    echo "CIME configuration already exists at ${CIME_CONFIG_DIR}, skipping."
fi

# Create case root directory if not present
if [ ! -d "${CASE_ROOT}" ]; then
    mkdir -p "${CASE_ROOT}"
    echo "Case directory created at ${CASE_ROOT}"
fi

echo ""
echo "CESM environment ready."
echo "  Source tree:  ${CESM_SRCROOT} (read-only)"
echo "  Case root:    ${CASE_ROOT}"
echo "  CIME config:  ${CIME_CONFIG_DIR}"
echo ""
echo "To create a new case:"
echo "  ${CESM_SRCROOT}/cime/scripts/create_newcase \\"
echo "      --case ${CASE_ROOT}/<casename> \\"
echo "      --res <resolution> --compset <compset> \\"
echo "      --machine <machine_name>"