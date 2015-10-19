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
# NOTE: Execute this on your master machine.
DIR=$1
SIZE=$2
PROJECT=$3
ROOT_NFS=/var/export
HOST=master.devops.org
SSH_USER=root

die () {
    echo >&2 "$@"
    exit 1
}

execute-ssh () {
	ssh $SSH_USER@$HOST "$1"
}

create-pv () {
cont=$(oc get pv  | grep "^$DIR " | wc -l)
if [ $cont -eq 0 ];then
oc create -f -<< EOF
apiVersion: v1
kind: PersistentVolume
metadata:
  name: $DIR
spec:
  capacity:
    storage: ${SIZE}Gi
  accessModes:
    - ReadWriteOnce
    - ReadWriteMany
  persistentVolumeReclaimPolicy: Recycle
  nfs:
    server: $HOST
    path: $ROOT_NFS/$DIR
EOF
else
        echo "PV already exists, skipping creation..."
fi
}

create-pvc () {
	cont=$(oc get pvc  | grep "^claim-$DIR " | wc -l)
	if [ $cont -eq 0 ];then
	oc project $PROJECT && \
oc create -f -<< EOF
kind: PersistentVolumeClaim
apiVersion: v1
metadata:
  name: claim-$DIR
spec:
  accessModes:
    - ReadWriteOnce
    - ReadWriteMany
  resources:
    requests:
      storage: ${SIZE}Gi
EOF
	else
		echo "PVC already exists, skipping creation..."
	fi
}

pv-isvalid () {
        cont=$(oc get pv  | grep "^kratos " | wc -l)
        if [ $cont -eq 0 ];then
                return 0
        else
                return 1
        fi
}

[ "$#" -eq 3 ] || die "Usage: $0 <directory> <size-in-gb> <project> "

if [ ! -d $ROOT_NFS/$DIR ]; then
	mkdir -p "$ROOT_NFS/$DIR"
fi
chown -R nfsnobody: "$ROOT_NFS/$DIR"
chmod 777 "$ROOT_NFS/$DIR"

cont=$(grep "$ROOT_NFS/$DIR" /etc/exports|wc -l)
if [ $cont -eq 0 ]; then
  echo "$ROOT_NFS/$DIR          *(rw,sync,no_root_squash)" >> /etc/exports
  exportfs -a
else
  echo "Directory $DIR already exists on /etc/exports. Skipping creation..."
fi

create-pv
create-pvc
