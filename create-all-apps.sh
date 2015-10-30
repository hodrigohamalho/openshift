echo "creating app Nexus..."
oc new-app sonatype/nexus -l 'app=nexus' && \
oc expose service nexus
echo "attaching volume to nexus"
oc volume dc/gitlab-ce --add --overwrite -t persistentVolumeClaim \
--claim-name=claim-gitlab-etc --name=gitlab-ce-volume-1

echo "creating app Gitlab-ce"
oc new-app gitlab/gitlab-ce:8.0.3-ce.1 -l 'app=gitlab-ce'
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
             -l "app=jenkins-redhat" && \
oc expose service jenkins-1-rhel7
echo "attaching volume to jenkins"
oc volume dc/jenkins-1-rhel7 \
            --add --overwrite -t persistentVolumeClaim \
            --claim-name=claim-jenkins \
            --name=jenkins-1-rhel7-volume-1

