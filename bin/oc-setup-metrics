#!/bin/bash
# @author Rafael Tuelho - rsoares@redhat.com

DOMAIN=$(grep subdomain /etc/origin/master/master-config.yaml | cut -d '"' -f2)

echo -e "\n --- \n Configuring Metrics Components \n --- \n"
echo -e "\t Service Accounts"
echo -e "\t\t Create a metrics-deployer service account:"

oc project openshift-infra

oc create -f - <<API
apiVersion: v1
kind: ServiceAccount
metadata:
  name: metrics-deployer
secrets:
- name: metrics-deployer
API

echo -e "\t\t grant the edit permission for the openshift-infra project:"
oadm policy add-role-to-user \
    edit system:serviceaccount:openshift-infra:metrics-deployer

echo -e "\t\t grant the cluster-reader permission to heapster service account:"
oadm policy add-cluster-role-to-user \
    cluster-reader system:serviceaccount:openshift-infra:heapstera

echo -e "\tMetric deployer will generate a self-signed certificate to be used"
echo -e "\t\t create a dummy secret that does not specify a certificate value:"
oc secrets new metrics-deployer nothing=/dev/null

echo -e "\t Deploying metric components using Default provided template (/usr/share/openshift/examples/infrastructure-templates/enterprise/metrics-deployer.yaml)"
echo -e "\t\t Deploying without Persistent Storage..."
oc process -f /usr/share/openshift/examples/infrastructure-templates/enterprise/metrics-deployer.yaml -v \
    HAWKULAR_METRICS_HOSTNAME=hawkular-metrics.$DOMAIN,USE_PERSISTENT_STORAGE=false \
    | oc create -f -

echo -e "\t\t\t using 'hawkular-metrics.$DOMAIN' as hostname for Hawkular Metrics component"

echo -e "\t Configuring Openshift Master config file to access hawkular metrics"
cp /etc/origin/master/master-config.yaml /etc/origin/master/master-config.yaml.bkp_`date +"%d%m%Y_%H%M"`
#sed -i "s|metricsPublicURL:.*|metricsPublicURL: \"https://hawkular-metrics.$DOMAIN/hawkular/metrics\"" /etc/origin/master/master-config.yaml

echo -e "\t IMPORTANT! \n\t\t>>> now access 'http://hawkular-metrics.$DOMAIN' and accept the Self signed Certificate in your web browser! \n"
echo -e "\t restart your master/node services if necessary!" 
echo -e "\n --- \n Finished \n --- \n"
