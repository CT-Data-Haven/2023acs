#!/usr/bin/env bash
townsyr=2023
# download reg_puma_list.rds from towns repo release
gh release download metadata \
    --repo "CT-Data-Haven/towns${townsyr}" \
    --pattern "reg_puma_list.rds" \
    --dir utils \
    --clobber

# download indicator_headings.txt from scratchpad repo release
# turn off for now---need website column
# gh release download meta \
#     --repo "CT-Data-Haven/scratchpad" \
#     --pattern "acs_indicator_headings.txt" \
#     --dir utils \
#     --clobber

# mv utils/acs_indicator_headings.txt utils/indicator_headings.txt