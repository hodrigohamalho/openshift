#!/bin/bash
# Envinronment parameters
#APP_HOSTNAME=gestaoprestador24h-dsv.openshift.sulamerica.br
#APP_NAME=gestaoprestador24h
#APP_GIT=http://gitlab-ce-devops.openshift.sulamerica.br/sulamerica/gestaoprestador24h.git
#APP_GIT_REF=
#APP_GIT_CONTEXT_DIR=
#USER_NAME=sulamerica
#OSE_SERVER=https://s01lab06.sulamerica.br:8443
#CERT_PATH=/var/jenkins_home/secrets/ca.crt
#DEVEL_PROJ_NAME=dsv
#LABELS


export PATH=$PATH:/var/jenkins_home/bin
oc login -u$USER_NAME -p$USER_PASSWD --server=$OSE_SERVER --insecure-skip-tls-verify
oc project $DEVEL_PROJ_NAME

BUILD_CONFIG=$(oc get bc | tail -1 | awk '{print $1}')

if [ -z "$BUILD_CONFIG" -o $BUILD_CONFIG == "NAME" ]; then
  echo "Create a new app"
  oc new-app --name=$APP_NAME --strategy=docker $APP_GIT -l name=$APP_NAME,$LABELS

echo "Find build id"
  BUILD_ID=`oc get builds | tail -1 | awk '{print $1}'`
  rc=1
  attempts=75
  count=0
  while [ $rc -ne 0 -a $count -lt $attempts ]; do
    BUILD_ID=`oc get builds | tail -1 | awk '{print $1}'`
    if [ $BUILD_ID == "NAME" ]; then
      count=$(($count+1))
      echo "Attempt $count/$attempts"
      sleep 5
    else
      rc=0
      echo "Build Id is :" ${BUILD_ID}
    fi
  done

  if [ $rc -ne 0 ]; then
    echo "Fail: Build could not be found after maximum attempts"
    exit 1
  fi
else
  BUILD_ID=`oc start-build ${BUILD_CONFIG}`
fi

echo "Waiting for build to start"
rc=1
attempts=25
count=0
while [ $rc -ne 0 -a $count -lt $attempts ]; do
  status=`oc get build ${BUILD_ID} -t '{{.status.phase}}'`
  if [[ $status == "Failed" || $status == "Error" || $status == "Canceled" ]]; then
    echo "Fail: Build completed with unsuccessful status: ${status}"
    exit 1
  fi
  if [ $status == "Complete" ]; then
    echo "Build completed successfully, will test deployment next"
    rc=0
  fi

  if [ $status == "Running" ]; then
    echo "Build started"
    rc=0
  fi

  if [ $status == "Pending" ]; then
    count=$(($count+1))
    echo "Attempt $count/$attempts"
    sleep 5
  fi
done

# stream the logs for the build that just started
oc build-logs $BUILD_ID



echo "Checking build result status"
rc=1
count=0
attempts=100
while [ $rc -ne 0 -a $count -lt $attempts ]; do
  status=`oc get build ${BUILD_ID} -t '{{.status.phase}}'`
  if [[ $status == "Failed" || $status == "Error" || $status == "Canceled" ]]; then
    echo "Fail: Build completed with unsuccessful status: ${status}"
    exit 1
  fi

  if [ $status == "Complete" ]; then
    echo "Build completed successfully, will test deployment next"
    rc=0
  else
    count=$(($count+1))
    echo "Attempt $count/$attempts"
    sleep 5
  fi
done

if [ $rc -ne 0 ]; then
    echo "Fail: Build did not complete in a reasonable period of time"
    exit 1
fi


echo "Checking build result status"
rc=1
count=0
attempts=100
while [ $rc -ne 0 -a $count -lt $attempts ]; do
  status=`oc get build ${BUILD_ID} -t '{{.status.phase}}'`
  if [[ $status == "Failed" || $status == "Error" || $status == "Canceled" ]]; then
    echo "Fail: Build completed with unsuccessful status: ${status}"
    exit 1
  fi

  if [ $status == "Complete" ]; then
    echo "Build completed successfully, will test deployment next"
    rc=0
  else
    count=$(($count+1))
    echo "Attempt $count/$attempts"
    sleep 5
  fi
done

if [ $rc -ne 0 ]; then
    echo "Fail: Build did not complete in a reasonable period of time"
    exit 1
fi

# scale up the test deployment
RC_ID=`oc get rc | tail -1 | awk '{print $1}'`

echo "Scaling up new deployment $test_rc_id"
oc scale --replicas=1 rc $RC_ID


echo "Checking for successful test deployment at $HOSTNAME"
set +e
rc=1
count=0
attempts=100
while [ $rc -ne 0 -a $count -lt $attempts ]; do
  if curl -s --connect-timeout 2 $APP_HOSTNAME >& /dev/null; then
    rc=0
    break
  fi
  count=$(($count+1))
  echo "Attempt $count/$attempts"
  sleep 5
done
set -e

if [ $rc -ne 0 ]; then
    echo "Failed to access test deployment, aborting roll out."
    exit 1
fi


################################################################################
##Include development test scripts here and fail with exit 1 if the tests fail##
################################################################################
