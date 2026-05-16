#!/usr/bin/env bash
set -euo pipefail
git config --global user.name "callum"
git config --global user.email "ct@deliowealth.com"
git config --global core.editor "vim"
git config --global pull.ff true
git config --global pull.rebase false
git config --global push.autoSetupRemote true
