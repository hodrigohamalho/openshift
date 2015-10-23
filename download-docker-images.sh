# @author Rodrigo Ramalho - hodrigohamalho@gmail.com / rramalho@redhat.com

echo "Starting download procces... "
docker pull sonatype/nexus && \
docker pull gitlab/gitlab-ce:8.0.3-ce.1v && \
docker pull registry.access.redhat.com/openshift3/jenkins-1-rhel7 && \
docker pull codenvy/che
