## Setup Guide: claude_city on EC2 / k3s
## (Windows Server 2022 Workspaces)

Docker Desktop requires nested virtualisation that AWS Workspaces does not reliably
provide. All Docker work (build + push) runs on the EC2 instance directly.
The Workspaces machine is used only for: Terraform, kubectl, SSH, and the browser.

All shell commands below are PowerShell unless a block is explicitly labelled
"On EC2 (bash)".

---

### Prerequisites (on Workspaces — PowerShell, run once)

**AWS CLI**
Download and run the MSI installer, then open a new PowerShell window:
  https://awscli.amazonaws.com/AWSCLIV2.msi

**Terraform**
Download the Windows AMD64 zip from https://developer.hashicorp.com/terraform/install,
extract terraform.exe, and place it in any directory on PATH (e.g. C:\Windows\System32).

Verify both:
```powershell
aws --version
terraform -version   # must be >= 1.6
```

**OpenSSH Client** (usually pre-installed on Server 2022; enable if missing):
```powershell
Add-WindowsCapability -Online -Name OpenSSH.Client~~~~0.0.1.0
```

**kubectl**
```powershell
curl.exe -LO "https://dl.k8s.io/release/v1.30.0/bin/windows/amd64/kubectl.exe"
Move-Item .\kubectl.exe C:\Windows\System32\kubectl.exe
kubectl version --client
```

---

### Step 0 — Get the code onto Workspaces (Git)

**One-time: create `.gitignore` and push from your local machine (Mac/bash)**

Add a `.gitignore` at the repo root before pushing — `terraform.tfvars` contains
environment-specific values (VPC IDs, key names) and must stay off the remote:

```bash
cat > .gitignore <<'EOF'
# Terraform
infrastructure/terraform.tfvars
infrastructure/.terraform/
infrastructure/.terraform.lock.hcl
infrastructure/terraform.tfstate
infrastructure/terraform.tfstate.backup

# Python
__pycache__/
*.pyc
.pytest_cache/
EOF

git add .
git commit -m "Initial scaffold, infrastructure, and build guide"
git remote add origin https://github.com/<your-org>/<your-repo>.git
git push -u origin main
```

**One-time: clone on Workspaces (PowerShell)**

```powershell
git clone https://github.com/<your-org>/<your-repo>.git
cd <your-repo>
```

**Before each session: pull latest changes**

```powershell
git pull
```

---

### Loading ephemeral AWS credentials

Ephemeral keys carry a session token that `aws configure` silently drops.
Export all three components as environment variables at the start of every session:

```powershell
$env:AWS_ACCESS_KEY_ID     = "<access-key-id>"
$env:AWS_SECRET_ACCESS_KEY = "<secret-access-key>"
$env:AWS_SESSION_TOKEN     = "<session-token>"

# Verify the identity loaded correctly
aws sts get-caller-identity
```

Terraform reads these same environment variables automatically — no provider-level
credential config is needed.

When keys expire mid-session, re-export new values and re-run any failed command.
Nothing on the EC2 instance is affected; it uses the instance IAM role independently.

---

### Shell variables (set after loading credentials)

```powershell
$REGION   = aws configure get region
$KEY_NAME = "<your-key-pair-name>"   # existing EC2 key pair (no .pem extension)
$KEY_PATH = "$HOME\.ssh\$KEY_NAME.pem"
```

`$EC2_IP` and `$ECR_URI` are read from Terraform outputs after apply (Step 2).

---

### Step 1 — Configure Terraform variables

```powershell
cd infrastructure
Copy-Item terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars` and fill in:
- `vpc_id`         — VPC in the testing account where the EC2 will be deployed
- `subnet_id`      — must have internet access (IGW or NAT GW) for k3s/Docker install
- `key_name`       — existing EC2 key pair name in the testing account
- `region`         — AWS region (default: us-east-1)
- `allowed_cidrs`  — list of public IPs (as /32) allowed to SSH and reach NodePort 30080;
                     include the Workspaces public IP (production account) and your home IP:

```hcl
allowed_cidrs = [
  "203.0.113.10/32",  # AWS Workspaces public IP
  "198.51.100.42/32", # home public IP
]
```

To find each IP: browse to https://checkip.amazonaws.com from that machine.

---

### Step 2 — Run Terraform

```powershell
# Still inside infrastructure/
terraform init
terraform plan    # review: IAM role, instance profile, ECR repo, SG, EC2 instance
terraform apply   # type "yes" to confirm
```

Terraform provisions:
- IAM role (`cityapp-ec2-role`) with ECR read and Secrets Manager access
- ECR repository (`claude_city`)
- Security group allowing SSH (22) and NodePort (30080) from Workspaces
- EC2 t3.medium with Docker + k3s installed via user data

Capture the outputs into shell variables for the remaining steps:

```powershell
$EC2_IP  = terraform output -raw ec2_private_ip
$ECR_URI = terraform output -raw ecr_repository_uri
```

> user_data runs in the background after the instance launches. Wait ~2 minutes
> before SSH-ing so that Docker and k3s are fully installed.

---

### Step 3 — Copy Source Code to EC2

From the repo root on Workspaces:

```powershell
cd ..   # back to repo root
scp -i $KEY_PATH -r .\claude_city ec2-user@${EC2_IP}:~/claude_city
```

---

### Step 4 — Verify Docker and k3s (on EC2)

```powershell
ssh -i $KEY_PATH ec2-user@$EC2_IP
```

```bash
# On EC2 (bash)
docker version          # must show Server running
kubectl get nodes       # node should show Ready
```

If either command fails, user_data may still be running:
```bash
sudo journalctl -u cloud-final -f   # follow until it exits
```

---

### Step 5 — Build and Push the Docker Image (on EC2)

```bash
# On EC2 (bash)
REGION=$(curl -s http://169.254.169.254/latest/meta-data/placement/region)
ACCOUNT=$(aws sts get-caller-identity --query Account --output text)
ECR_URI="$ACCOUNT.dkr.ecr.$REGION.amazonaws.com/claude_city"

aws ecr get-login-password --region $REGION | \
  docker login --username AWS --password-stdin $ACCOUNT.dkr.ecr.$REGION.amazonaws.com

cd ~/claude_city
docker build -t claude_city .
docker tag claude_city:latest $ECR_URI:latest
docker push $ECR_URI:latest
```

The EC2 instance role handles ECR authentication — no Workspaces credentials needed here.

---

### Step 6 — Configure kubectl on Workspaces

user_data already copied the kubeconfig to `/home/ec2-user/.kube/config`.
Copy it to Workspaces and patch the server address:

```powershell
New-Item -ItemType Directory -Force "$HOME\.kube" | Out-Null
scp -i $KEY_PATH ec2-user@${EC2_IP}:/home/ec2-user/.kube/config "$HOME\.kube\cityapp.yaml"

(Get-Content "$HOME\.kube\cityapp.yaml") `
  -replace 'https://127\.0\.0\.1:6443', "https://${EC2_IP}:6443" |
  Set-Content "$HOME\.kube\cityapp.yaml"

$env:KUBECONFIG = "$HOME\.kube\cityapp.yaml"
# To persist across sessions:
#   Add-Content $PROFILE "`n`$env:KUBECONFIG = `"$HOME\.kube\cityapp.yaml`""

kubectl get nodes   # should show the EC2 node as Ready
```

---

### Step 7 — Download world.sql (on EC2)

```bash
# On EC2 (bash)
curl -L https://downloads.mysql.com/docs/world-db.zip -o /tmp/world-db.zip
unzip /tmp/world-db.zip -d /tmp/
mkdir -p ~/claude_city/mysql
mv /tmp/world-db/world.sql ~/claude_city/mysql/world.sql
rm -rf /tmp/world-db /tmp/world-db.zip
```

---

### Step 8 — Create Namespace, ECR Pull Secret, and MySQL ConfigMap

```powershell
# On Workspaces — requires valid ephemeral credentials
aws sts get-caller-identity   # confirm keys are still valid

kubectl create namespace cityapp

# ECR tokens expire after 12 hours — re-run before every demo session
$ECR_PASS = aws ecr get-login-password --region $REGION
kubectl create secret docker-registry ecr-pull-secret `
  --docker-server="$ECR_URI".Split("/")[0] `
  --docker-username=AWS `
  --docker-password=$ECR_PASS `
  --namespace=cityapp
```

Create the database credentials Secret on EC2 (keeps plaintext out of Deployment manifests).
Choose a strong password — do not use a real credential here and do not commit this value anywhere:

```bash
# On EC2 (bash)
DB_PASSWORD='<choose-a-strong-password>'
kubectl create secret generic cityapp-db-credentials \
  --from-literal=root-password="$DB_PASSWORD" \
  --from-literal=db-password="$DB_PASSWORD" \
  -n cityapp
unset DB_PASSWORD
```

Create the MySQL init ConfigMap from world.sql on EC2:

```bash
# On EC2 (bash)
kubectl create configmap mysql-init-sql \
  --from-file=world.sql=/home/ec2-user/claude_city/mysql/world.sql \
  -n cityapp
```

> world.sql is ~90 KB, well under the 1 MB ConfigMap limit. MySQL runs it
> automatically from /docker-entrypoint-initdb.d/ on first container startup.

---

### Step 9 — Apply Kubernetes Manifests

Create a `k8s\` directory in the repo and save these five files.
The image URI for 04-app-deployment.yaml is the `$ECR_URI` Terraform output.

**k8s\01-serviceaccount.yaml**
```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: cityapp-sa
  namespace: cityapp
```

**k8s\02-mysql-deployment.yaml**
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: mysql
  namespace: cityapp
spec:
  selector:
    matchLabels:
      app: mysql
  template:
    metadata:
      labels:
        app: mysql
    spec:
      containers:
        - name: mysql
          image: mysql:8.0
          env:
            - name: MYSQL_ROOT_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: cityapp-db-credentials
                  key: root-password
            - name: MYSQL_DATABASE
              value: world
          ports:
            - containerPort: 3306
          volumeMounts:
            - name: init-sql
              mountPath: /docker-entrypoint-initdb.d
            - name: data
              mountPath: /var/lib/mysql
      volumes:
        - name: init-sql
          configMap:
            name: mysql-init-sql
        - name: data
          emptyDir: {}
```

**k8s\03-mysql-service.yaml**
```yaml
apiVersion: v1
kind: Service
metadata:
  name: mysql
  namespace: cityapp
spec:
  selector:
    app: mysql
  ports:
    - port: 3306
      targetPort: 3306
```

**k8s\04-app-deployment.yaml**
Replace <ECR_REPOSITORY_URI> with the value of `terraform output ecr_repository_uri`.

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: cityapp
  namespace: cityapp
spec:
  selector:
    matchLabels:
      app: cityapp
  template:
    metadata:
      labels:
        app: cityapp
    spec:
      serviceAccountName: cityapp-sa
      imagePullSecrets:
        - name: ecr-pull-secret
      containers:
        - name: cityapp
          image: <ECR_REPOSITORY_URI>:latest
          env:
            - name: MODE
              value: env
            - name: DBADDR
              value: mysql
            - name: DBUSER
              value: root
            - name: DBPASS
              valueFrom:
                secretKeyRef:
                  name: cityapp-db-credentials
                  key: db-password
          ports:
            - containerPort: 8080
```

**k8s\05-app-service.yaml**
```yaml
apiVersion: v1
kind: Service
metadata:
  name: cityapp
  namespace: cityapp
spec:
  type: NodePort
  selector:
    app: cityapp
  ports:
    - port: 8080
      targetPort: 8080
      nodePort: 30080
```

Apply from Workspaces:
```powershell
kubectl apply -f .\k8s\
```

---

### Step 10 — Verify the Deployment

```powershell
# Watch pods — MySQL takes ~30 s to load world.sql on first boot
kubectl get pods -n cityapp -w

# Expected steady state:
# NAME                       READY   STATUS    RESTARTS   AGE
# mysql-xxxxx                1/1     Running   0          2m
# cityapp-xxxxx              1/1     Running   0          2m
```

Open in the Workspaces browser:  http://<EC2_PRIVATE_IP>:30080
($EC2_IP from Step 2)

You should see a random world city with the grey "Environment Variables" badge.

---

### Teardown

```powershell
kubectl delete namespace cityapp   # removes all k8s resources
cd infrastructure
terraform destroy                  # removes EC2, SG, ECR repo (+ all images), IAM role
```

---

### Quick-reference: ECR secret refresh before a demo

```powershell
# Confirm credentials are still valid first
aws sts get-caller-identity

kubectl delete secret ecr-pull-secret -n cityapp
$ECR_PASS = aws ecr get-login-password --region $REGION
kubectl create secret docker-registry ecr-pull-secret `
  --docker-server="$ECR_URI".Split("/")[0] `
  --docker-username=AWS `
  --docker-password=$ECR_PASS `
  --namespace=cityapp
kubectl rollout restart deployment/cityapp -n cityapp
```

### Switching credential modes

```powershell
kubectl set env deployment/cityapp -n cityapp MODE=conjur   # or ccp / secrets-hub
kubectl rollout status deployment/cityapp -n cityapp
```
