#!/bin/bash
#
# The entrypoint removes the previous mount-path and does a fresh
# checkout of the repository. It also initializes git lfs and sets
# the proper file permissions.
set -x

if [ "$LFS_AUTO_FETCH" = 1 ]; then
  LFS_SKIP_SMUDGE="";
else
  LFS_SKIP_SMUDGE="--skip-smudge";
fi

rm -rf ${MOUNT_PATH}/*
(rm -rf ${MOUNT_PATH}/.* || true)
git config --system push.default simple
git lfs install $LFS_SKIP_SMUDGE --system
git clone $REPOSITORY ${MOUNT_PATH}
git lfs install $LFS_SKIP_SMUDGE --local

# Trying to recover from a relevant autosave branch
REMOTES_ORIGIN="remotes/origin/"
AUTOSAVE_BRANCH_PREFIX="renku/autosave/$JUPYTERHUB_USER"

GIT_FETCH_OUT=`git fetch && git branch -a`
IFS=$'\n' ALL_BRANCHES=($GIT_FETCH_OUT)
for branch in "${ALL_BRANCHES[@]}"
do
    if [[ $branch == *"${REMOTES_ORIGIN}${AUTOSAVE_BRANCH_PREFIX}/${BRANCH}/${COMMIT_SHA:0:7}"* ]] ; then
        AUTOSAVE_REMOTE_BRANCH=${branch// /}
    fi
done

if [ -z "$AUTOSAVE_REMOTE_BRANCH" ] ; then
  (git checkout ${BRANCH} || git checkout -b ${BRANCH})
  git submodule init && git submodule update
  git reset --hard $COMMIT_SHA

  chown ${USER_ID}:${GROUP_ID} -Rc ${MOUNT_PATH}
  exit 0
fi

IFS='/' read -r -a AUTOSAVE_REMOTE_BRANCH_ITEMS <<< "$AUTOSAVE_REMOTE_BRANCH"

if [ "${#AUTOSAVE_REMOTE_BRANCH_ITEMS[@]}" -lt 7 ] ; then
  echo "Auto-save branch is in the wrong format; cannot recover the state from that branch"
  exit 0
fi

PRE_SAVE_BRANCH_NAME=${AUTOSAVE_REMOTE_BRANCH_ITEMS[5]}
(git checkout ${PRE_SAVE_BRANCH_NAME} || git checkout -b ${PRE_SAVE_BRANCH_NAME})
git submodule init && git submodule update

PRE_SAVE_LOCAL_COMMIT_SHA=${AUTOSAVE_REMOTE_BRANCH_ITEMS[7]}
git reset --hard $PRE_SAVE_LOCAL_COMMIT_SHA

AUTOSAVE_BRANCH=${AUTOSAVE_REMOTE_BRANCH/$REMOTES_ORIGIN/''}
git pull --rebase origin $AUTOSAVE_BRANCH
git reset --soft $PRE_SAVE_LOCAL_COMMIT_SHA
git reset HEAD .
git push origin :"$AUTOSAVE_BRANCH"

chown ${USER_ID}:${GROUP_ID} -Rc ${MOUNT_PATH}
