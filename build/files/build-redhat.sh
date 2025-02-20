#!/bin/bash

IMAGE_NAME=$1
BASE_IMAGE_TYPE=$2
VERSION_TRACK_PACKAGE=$3
shift 3
INSTALL_PACKAGES=${@}


REPO_VERSION=$(
    dnf info $VERSION_TRACK_PACKAGE 2>/dev/null \
    | awk '$1~/Version|Release/ {printf "%s-", $3}' \
    | head -c -1
)
EXISTING_VERSION=$(
    IMGS=$(buildah images);
    IMG_ID=$(awk '/^localhost\/'$IMAGE_NAME' *latest / {print $3}' <<< $IMGS);
    awk '/^localhost\/'$IMAGE_NAME' .*-.*'"${IMG_ID}"' / {print $2}' <<< $IMGS;
)
NEWER_VERSION=$(
    echo -e "$REPO_VERSION\n$EXISTING_VERSION" \
    | sort -V \
    | tail -n1
)
if [[ "$EXISTING_VERSION" == "$NEWER_VERSION" ]]; then
    echo "Already version $EXISTING_VERSION"
    exit 0
fi


function ubi_micro () {

    CONTAINER=$(buildah from ubi9-micro);
    MOUNT=$(buildah mount $CONTAINER);
    [[ -z $MOUNT ]] && exit 1;

    dnf install --installroot $MOUNT --releasever 9 --nodocs -y $INSTALL_PACKAGES;
    dnf clean all --installroot $MOUNT;
    rm -rf  $MOUNT/var/lib/rpm \
            $MOUNT/var/lib/dnf \
            $MOUNT/var/cache \
            $MOUNT/var/log/*;
    buildah umount $CONTAINER;
    buildah commit $CONTAINER ${IMAGE_NAME}:${REPO_VERSION};
    buildah tag ${IMAGE_NAME}:${REPO_VERSION} ${IMAGE_NAME}:latest;

}

if [[ $BASE_IMAGE_TYPE -eq "ubi-micro" ]]; then
    ubi_micro
fi
