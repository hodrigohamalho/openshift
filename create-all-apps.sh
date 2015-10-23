# @author Rodrigo Ramalho - hodrigohamalho@gmail.com / rramalho@redhat.com

echo "To turn this process faster, you should eager download all docker images"
echo "using download-docker-images.sh on the node that will host all apps"
echo ""

echo "creating app Nexus..."
oc new-app sonatype/nexus -l 'app=nexus,region=devops' && \
oc expose service nexus
echo "attaching volume to nexus"
oc volume dc/nexus \
        --add --overwrite -t persistentVolumeClaim \
        --claim-name=claim-nexus --name=nexus-volume-1

echo "creating app Gitlab-ce"
oc new-app gitlab/gitlab-ce:8.0.3-ce.1 -l 'app=gitlab-ce,region=devops'
oc expose service gitlab-ce
echo "attaching volume to gitlab..."
oc volume dc/gitlab-ce --add --overwrite -t persistentVolumeClaim \
  --claim-name=claim-gitlab-etc --name=gitlab-ce-volume-1
oc volume dc/gitlab-ce --add --overwrite -t persistentVolumeClaim \
  --claim-name=claim-gitlab-log --name=gitlab-ce-volume-2
oc volume dc/gitlab-ce --add --overwrite -t persistentVolumeClaim \
  --claim-name=claim-gitlab-opt --name=gitlab-ce-volume-3

echo "creating app Jenkins from Redhat"
oc new-app registry.access.redhat.com/openshift3/jenkins-1-rhel7 -l \
             -e "JENKINS_PASSWORD=redhat" \
             -l "app=jenkins-redhat,region=devops" && \
oc expose service jenkins-1-rhel7
echo "attaching volume to jenkins"
oc volume dc/jenkins-1-rhel7 \
            --add --overwrite -t persistentVolumeClaim \
            --claim-name=claim-jenkins \
            --name=jenkins-1-rhel7-volume-1

echo "creating app cloud eclipse"
oc new-app codenvy/che -l 'app=eclipse,region=devops' && \
oc expose che

echo "Monitor events and pods to check the progress..."
echo "oc get events  --watch"
echo "oc get pods  --watch"
