if [ -z "$AUTH_TOKEN" ]; then
  AUTH_TOKEN=`cat /var/run/secrets/kubernetes.io/serviceaccount/token`
fi

if [ -e /run/secrets/kubernetes.io/serviceaccount/ca.crt ]; then
  alias oc="oc -n $PROJECT --token=$AUTH_TOKEN --server=$OPENSHIFT_API_URL --certificate-authority=/run/secrets/kubernetes.io/serviceaccount/ca.crt "
else
  alias oc="oc -n $PROJECT --token=$AUTH_TOKEN --server=$OPENSHIFT_API_URL --insecure-skip-tls-verify "
fi

TEST_ENDPOINT=`oc get service ${SERVICE} -t '{{.spec.clusterIP}}{{":"}}{{ $a:= index .spec.ports 0 }}{{$a.port}}'`

echo "none" > old_rc_id
oc get rc -t '{{ range .items }}{{.spec.selector.deploymentconfig}}{{" "}}{{.metadata.name}}{{"\n"}}{{end}}' | grep -e "^$DEPLOYMENT_CONFIG " | awk '{print $2}' | while read -r test_rc_id; do
  echo "Scaling down old deployment $test_rc_id"
  oc scale --replicas=0 rc $test_rc_id
  echo $test_rc_id > old_rc_id
done
old_rc_id=`cat old_rc_id`


# wait for old pods to be torn down
# TODO should poll instead.
sleep 5

echo "Triggering new application build and deployment"
BUILD_ID=`oc start-build ${BUILD_CONFIG}`

# stream the logs for the build that just started
rc=1
count=0
attempts=3
set +e
while [ $rc -ne 0 -a $count -lt $attempts ]; do
  oc build-logs $BUILD_ID
  rc=$?
  count=$(($count+1))
done
set -e

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
# if this gets scaled up before the new deployment occurs from the build,
# bad things happen...need to make sure a new deployment has occurred first.
count=0
attempts=20
new_rc_id="none"
echo "none" > new_rc_id
while [ $new_rc_id == $old_rc_id -a $count -lt $attempts ]; do
  oc get rc -t '{{ range .items }}{{.spec.selector.deploymentconfig}}{{" "}}{{.metadata.name}}{{"\n"}}{{end}}' | grep -e "^$DEPLOYMENT_CONFIG " | awk '{print $2}' | while read -r test_rc_id; do
    echo $test_rc_id > new_rc_id
  done
  new_rc_id=`cat new_rc_id`
  count=$(($count+1))
  sleep 1
done
if [ $count -eq $attempts ]; then
  echo "Failure: Never found new deployment"
  exit 1
fi

oc get rc -t '{{ range .items }}{{.spec.selector.deploymentconfig}}{{" "}}{{.metadata.name}}{{"\n"}}{{end}}' | grep -e "^$DEPLOYMENT_CONFIG " | awk '{print $2}' | while read -r test_rc_id; do
  # at the end of this loop, 'test_rc_id' will contain the id of the last deployment in the list
  # should be the most recent.
  echo $test_rc_id > test_rc_id
done

test_rc_id=`cat test_rc_id`
echo "Scaling up new deployment $test_rc_id"
oc scale --replicas=1 rc $test_rc_id

echo "Checking for successful test deployment at $TEST_ENDPOINT"
set +e
rc=1
count=0
attempts=100
while [ $rc -ne 0 -a $count -lt $attempts ]; do
  if curl -s --connect-timeout 2 $TEST_ENDPOINT >& /dev/null; then
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


# Tag the image into production
echo "Test deployment succeeded, rolling out to production..."
oc tag $TEST_IMAGE_TAG $PRODUCTION_IMAGE_TAG
      
