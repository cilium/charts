#!/bin/bash

CWD=$(dirname $(readlink -ne $BASH_SOURCE))

set -e

CILIUM_DIR=$1
if [ $# -lt 1 ] || [ ! -d $CILIUM_DIR ]; then
	echo "usage: $0 </path/to/cilium/repository>" 1>&2
	exit 1
fi

if [ ! -e $CILIUM_DIR/install/kubernetes/cilium/values.yaml ]; then
	echo "Did you specify a Cilium repository path correctly?"
	echo "command: $0 $1"
	exit 1
fi

VERSION=$(cat $CILIUM_DIR/VERSION)
cd $CILIUM_DIR/install/kubernetes
helm package --destination "$CWD" cilium
cd -
helm repo index . --merge index.yaml
$EDITOR README.md
git add README.md index.yaml cilium-$VERSION.tgz
git commit -s -m "Add $VERSION@$(cd $CILIUM_DIR; git rev-parse HEAD) ⎈"
