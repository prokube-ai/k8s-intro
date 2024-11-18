#/usr/bin/env sh

if [[ -z "${USER}" ]]; then
    echo '$USER not defined. Exiting'
    exit 1
fi
echo "Creating setup for user: $USER"
NAMESPACE=$USER
GROUPNAME=developers
CLUSTERNAME=microk8s-cluster

CSR_FILE=$USER.csr
KEY_FILE=$USER.key
CRT_FILE=$USER.crt
CERTIFICATE_NAME=$USER.$NAMESPACE
KONFIG_FILE=$USER.config
KONTEXT=$USER-context

mkdir $USER-config
cd $USER-config

# We didn't find another way of getting the server address out of the active context
# the yq expressions should be fine (TM) because names should be unique in each array
CURRENT_CONTEXT=$(kubectl config current-context)
echo "current context: $CURRENT_CONTEXT"
CLUSTER_NAME=$(kubectl config view | yq ".contexts | map(select(.name == \"$CURRENT_CONTEXT\")) | .[].context.cluster")
echo "current cluster name: $CLUSTER_NAME"
SERVER=$(kubectl config view | yq ".clusters | map(select(.name == \"$CLUSTER_NAME\" )) | .[].cluster.server")
echo "Current server: $SERVER"
echo "getting ca file"
kubectl config view --raw | yq ".clusters | map(select(.name == \"$CLUSTER_NAME\" )) | .[].cluster.certificate-authority-data" | base64 -d > ca.crt
unset CURRENT_CONTEXT
unset CLUSTER_NAME

openssl genrsa -out $KEY_FILE 2048
openssl req -new -key $KEY_FILE -out $CSR_FILE -subj "/CN=$USER/O=$GROUPNAME"


cat <<EOF | kubectl create -f -
apiVersion: certificates.k8s.io/v1
kind: CertificateSigningRequest
metadata:
  name: $CERTIFICATE_NAME
spec:
  groups:
  - system:authenticated
  request: $(cat $CSR_FILE | base64 | tr -d '\n')
  signerName: kubernetes.io/kube-apiserver-client
  usages:
  - digital signature
  - key encipherment
  - client auth
EOF

kubectl certificate approve $CERTIFICATE_NAME
kubectl get csr $CERTIFICATE_NAME -o jsonpath='{.status.certificate}'  | base64 -d > $CRT_FILE


cat <<EOF | kubectl create -f -
kind: Role
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  namespace: $NAMESPACE
  name: $USER-role
rules:
- apiGroups: ["", "extensions", "apps"]
  resources: ["deployments", "replicasets", "pods", "pods/portforward", "pods/log"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"] # You can also use ["*"] for all verbs
EOF


cat <<EOF | kubectl create -f -
kind: RoleBinding
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: $USER-role-binding
  namespace: $NAMESPACE
subjects:
- kind: User
  name: $USER
  apiGroup: ""
roleRef:
  kind: Role
  name: $USER-role
  apiGroup: ""
EOF

# creating a new config file including a cluster, user and context
kubectl config --kubeconfig $KONFIG_FILE set-cluster $CLUSTERNAME --server=$SERVER --certificate-authority ca.crt --embed-certs
kubectl config --kubeconfig $KONFIG_FILE set-credentials $USER --client-certificate=$CRT_FILE --client-key=$KEY_FILE --embed-certs
kubectl config --kubeconfig $KONFIG_FILE set-context $KONTEXT --cluster=$CLUSTERNAME --namespace=$NAMESPACE --user=$USER
kubectl config --kubeconfig $KONFIG_FILE use-context $KONTEXT


# print created config file
echo "############################################"
cat $KONFIG_FILE
