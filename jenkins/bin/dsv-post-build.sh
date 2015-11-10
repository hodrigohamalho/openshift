#!/bin/bash
# Envinronment parameters
#APP_HOSTNAME=app-monitor-dsv.cloud.devops.org
#APP_NAME=app-monitor
#APP_GIT=http://gitlab-ce-devops.cloud.devops.org/master.devops.org/gestaoprestador24h.git
#APP_GIT_REF=
#APP_GIT_CONTEXT_DIR=
#USER_NAME=master.devops.org
#OSE_SERVER=https://master.devops.org:8443
#CERT_PATH=/var/jenkins_home/secrets/ca.crt
#DEVEL_PROJ_NAME=dsv
#LABELS

export PATH=$PATH:/var/jenkins_home/bin
oc login -u$USER_NAME -p$USER_PASSWD --server=$OSE_SERVER --insecure-skip-tls-verify
oc project $DEVEL_PROJ_NAME

BUILD_CONFIG=$(oc get bc | grep $APP_NAME | awk '{print $1}')

if [ -z "$BUILD_CONFIG" ]; then
  echo "BuildConfig not found, creating $APP_NAME new app"
  oc new-app --name=$APP_NAME --strategy=docker $APP_GIT -l name=$APP_NAME,$LABELS &&
  echo "Creating route for service $APP_NAME"
  oc expose service $APP_NAME

  rc=1
  attempts=75
  count=0
  while [ $rc -ne 0 -a $count -lt $attempts ]; do
    BUILD_ID=$(oc get builds | grep $APP_NAME | awk '{print $1}')
    if [ -z $BUILD_ID ]; then
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
  echo "BuildConfig exists, starting a new build!"
  BUILD_ID=$(oc start-build ${BUILD_CONFIG})
fi

echo "Waiting for build to start"
rc=1
attempts=25
count=0
while [ $rc -ne 0 -a $count -lt $attempts ]; do
  status=$(oc get build ${BUILD_ID} -t '{{.status.phase}}')
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
  status=$(oc get build ${BUILD_ID} -t '{{.status.phase}}')
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
  status=$(oc get build ${BUILD_ID} -t '{{.status.phase}}')
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
RC_ID=`oc get rc | grep $APP_NAME | awk '{print $1}'`

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

echo "Evict cache"
oc get bc $APP_NAME -o yaml > bc-${APP_NAME}.yaml
if ! grep --quiet noCache bc-${APP_NAME}.yaml; then
  sed -i '/dockerStrategy/a \ \ \ \ \ \ nocache: true' bc-${APP_NAME}.yaml
  oc replace -f bc-${APP_NAME}.yaml
fi
rm -f bc-${APP_NAME}.yaml
