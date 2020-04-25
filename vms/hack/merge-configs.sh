mv ~/.kube/config ~/.kube/config_backup

KUBECONFIG=:~/admin.conf:~/.kube/config_backup kubectl config view --flatten > ~/.kube/config