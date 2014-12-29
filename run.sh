#/bin/bash

# Set envs here for convenience
export XPENZ_S3_KEY="this thing"
export XPENZ_S3_SECRET="that thing"
export XPENZ_S3_BUCKET="the other thing"

# Change this if running on a custom domain
export ROOT_URL="http://localhost:3000"

meteor
