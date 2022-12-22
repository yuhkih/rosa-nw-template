oc new-app --name test --image=quay.io/yuhkih0/hello-openshift -l app=test
oc :q!create edge service test
