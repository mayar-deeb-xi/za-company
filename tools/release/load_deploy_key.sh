#!/usr/bin/env bash
# Readies a deploy job's SSH, on a build machine only, for both deploys - the
# live one after a release and the dev one - so the two cannot drift apart:
#
#   tools/release/load_deploy_key.sh     (DEPLOY_SSH_KEY and HOST in the env)
#
# Writes the key from the DEPLOY_SSH_KEY secret, pins the server's host key
# from tools/release/known_hosts rather than learning it on the day (a deploy
# must refuse a server that is not ours), and puts the ssh command in $SSH for
# the steps after it. The key can run nothing on the server but
# server/deploy.sh (RELEASING.md, Deploying).

set -euo pipefail

if [ -z "${DEPLOY_SSH_KEY:-}" ]; then
  echo "::error::The DEPLOY_SSH_KEY secret is not set, so nothing was deployed. RELEASING.md, Deploying, says how to add it; then re-run this job."
  exit 1
fi
install -m 700 -d ~/.ssh
printf '%s\n' "$DEPLOY_SSH_KEY" > ~/.ssh/deploy
chmod 600 ~/.ssh/deploy
cp "$(dirname "$0")/known_hosts" ~/.ssh/known_hosts
echo "SSH=ssh -i $HOME/.ssh/deploy -o IdentitiesOnly=yes -o BatchMode=yes -o StrictHostKeyChecking=yes root@$HOST" >> "$GITHUB_ENV"
