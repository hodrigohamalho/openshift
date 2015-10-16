# @author Rodrigo Ramalho - hodrigohamalho@gmail.com / rramalho@redhat.com
# @author Waldirio Pinheiro - waldirio@gmail.com / waldirio@redhat.com
# This script creates:
# - nfs directory
# - persistence volume on openshift
# - persistence claim on openshift
# Parameters:
# 1. Directory to be create (every names, pv, pvc, nfs will be based on this name)
# 2. Size in Gb
# 3. Project in which pvc will be created
# Usage: ./create-storage jenkis-storage 5 desenvolvimento
# A storage

DIR=$1
SIZE=$2
PROJECT=$3
ROOT_NFS=/var/export
HOST=$(hostname)

die () {
    echo >&2 "$@"
    exit 1
}

create-pv () {
oc create -f -<< EOF
apiVersion: v1
kind: PersistentVolume
metadata:
  name: "$DIR"
spec:
  capacity:
    storage: "$SIZE"Gi
  accessModes:
    - ReadWriteOnce
    - ReadWriteMany
  persistentVolumeReclaimPolicy: Recycle
  nfs:
    server: "$HOST"
    path: "$ROOT_NFS/$DIR"
EOF
}

create-pvc () {
oc project $PROJECT && \
oc create -f -<< EOF
kind: PersistentVolumeClaim
apiVersion: v1
metadata:
  name: $DIR
spec:
  accessModes:
    - ReadWriteOnce
    - ReadWriteMany
  resources:
    requests:
      storage: "$SIZE"Gi
EOF
}

[ "$#" -eq 3 ] || die "Parameters are: $0 <directory> <size-in-gb> <project> "

# handle NFS
mkdir -p "$ROOT_NFS/$DIR"
chown -R nfsnobody: "$ROOT_NFS/$DIR"
chmod 777 "$ROOT_NFS/$DIR"
echo "$ROOT_NFS/$DIR 		*(rw,sync,no_root_squash)" >> /etc/exports
exportfs -a

create-pv
create-pvc
