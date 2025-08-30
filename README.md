# Flask Todo Application with DevOps Pipeline

A modern Flask-based Todo application featuring a complete CI/CD pipeline with containerization, Kubernetes deployment, Infrastructure as Code (Terraform), and comprehensive monitoring stack.
![App Screenshot](images/README.png)
![App Screenshot](images/Diagram.png)



## 🚀 Features

- **Flask Web Application**: Simple, responsive todo list with MongoDB backend
- **Containerized Deployment**: Docker-based application packaging
- **Kubernetes Orchestration**: Scalable deployment with load balancing
- **Infrastructure as Code**: AWS EKS cluster provisioned with Terraform
- **CI/CD Pipeline**: Automated testing, building, and deployment with GitHub Actions
- **Monitoring Stack**: Prometheus and Grafana for application and infrastructure monitoring
- **Multi-Registry Support**: Images pushed to both Docker Hub and GitHub Container Registry

## 📋 Table of Contents

- [Architecture](#architecture)
- [Prerequisites](#prerequisites)
- [Local Development](#local-development)
- [Infrastructure Setup](#infrastructure-setup)
- [Deployment](#deployment)
- [Monitoring](#monitoring)
- [CI/CD Pipeline](#cicd-pipeline)
- [Configuration](#configuration)
- [Troubleshooting](#troubleshooting)
- [Contributing](#contributing)

## 🏗️ Architecture

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   GitHub Repo   │───▶│  GitHub Actions │───▶│   Docker Hub    │
└─────────────────┘    └─────────────────┘    └─────────────────┘
                              │
                              ▼
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Terraform     │───▶│   AWS EKS       │───▶│   Kubernetes    │
│   (IaC)         │    │   Cluster       │    │   Workloads     │
└─────────────────┘    └─────────────────┘    └─────────────────┘
                              │
                              ▼
┌─────────────────┐    ┌─────────────────┐
│   Prometheus    │───▶│    Grafana      │
│   Monitoring    │    │   Dashboard     │
└─────────────────┘    └─────────────────┘
```

## 🔧 Prerequisites

### Local Development
- Python 3.8+
- Docker and Docker Compose
- MongoDB (local or containerized)

### Infrastructure & Deployment
- AWS CLI configured with appropriate permissions
- Terraform >= 1.1.7
- kubectl
- Helm 3.x
- GitHub account with repository secrets configured

### Required AWS Permissions
- EKS cluster creation/management
- VPC and networking resources
- EC2 instances (for EKS nodes)
- S3 bucket access (Terraform state)
- DynamoDB table access (Terraform locking)

## 💻 Local Development

### Quick Start

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd flask-todo-app
   ```

2. **Set up Python environment**
   ```bash
   python -m venv venv
   source venv/bin/activate  # On Windows: venv\Scripts\activate
   pip install -r requirements.txt
   ```

3. **Run MongoDB locally**
   ```bash
   # Using Docker
   docker run -d --name mongodb -p 27017:27017 mongo:5.0
   
   # Or using Docker Compose
   docker-compose up -d mongodb
   ```

4. **Configure environment variables**
   ```bash
   export MONGO_URI="mongodb://localhost:27017/"
   export MONGO_USERNAME="root"
   export MONGO_PASSWORD="secret"
   ```

5. **Run the application**
   ```bash
   python app.py
   ```

6. **Access the application**
   - Open http://localhost:5000 in your browser
   - Health check: http://localhost:5000/live

### Running with Docker

```bash
# Build the image
docker build -t todoapp .

# Run with MongoDB
docker run -d --name mongodb mongo:5.0
docker run -d --name todoapp -p 5000:5000 \
  -e MONGO_URI="mongodb://mongodb:27017/" \
  --link mongodb \
  todoapp
```

## 🏗️ Infrastructure Setup

### Prerequisites Setup

1. **Create S3 backend and DynamoDB table**
   ```bash
   # This is automated in the pipeline, but can be run manually:
   aws s3api create-bucket --bucket mokhaled-bucket-1286 --region us-east-1
   aws dynamodb create-table \
     --table-name terraform-lock \
     --attribute-definitions AttributeName=LockID,AttributeType=S \
     --key-schema AttributeName=LockID,KeyType=HASH \
     --billing-mode PAY_PER_REQUEST
   ```

### Deploy Infrastructure

```bash
cd Terraform/team1

# Initialize Terraform
terraform init

# Review the plan
terraform plan

# Apply infrastructure
terraform apply -auto-approve
```

This creates:
- VPC with public/private subnets
- EKS cluster (`sprints-cluster-0`)
- Node groups with auto-scaling
- Security groups and IAM roles

## 🚀Deployment

### Kubernetes Deployment

1. **Update kubeconfig**
   ```bash
   aws eks --region us-east-1 update-kubeconfig --name sprints-cluster-0
   ```

2. **Deploy the application**
   ```bash
   cd k8s
   
   # Deploy MongoDB
   kubectl apply -f mongodb-deployment.yml
   
   # Deploy the Flask application
   kubectl apply -f deployment.yml
   kubectl apply -f service.yml
   ```

3. **Verify deployment**
   ```bash
   kubectl get pods
   kubectl get services
   kubectl get ingress
   ```

### Manual Container Deployment

```bash
# Build and push to Docker Hub
docker build -t yourusername/todoapp:latest .
docker push yourusername/todoapp:latest

# Update deployment.yml with your image
kubectl set image deployment/flask-microservice flask-microservice=yourusername/todoapp:latest
```

## 📊 Monitoring

The application includes a comprehensive monitoring stack using the kube-prometheus-stack.

### Components
- **Prometheus**: Metrics collection and alerting
- **Grafana**: Visualization and dashboards
- **ServiceMonitor**: Custom application metrics

### Access Monitoring Services

1. **Get service URLs**
   ```bash
   kubectl -n monitoring get svc
   ```

2. **Access Grafana**
   - Get the LoadBalancer URL from the service
   - Username: `admin`
   - Password: Set via `GRAFANA_ADMIN_PASSWORD` secret

3. **Access Prometheus**
   - Get the LoadBalancer URL from the prometheus service
   - Default port: 9090

### Custom Metrics

The application exposes metrics at `/health` endpoint (configure as needed):
```yaml
# servicemonitor.yml configures Prometheus to scrape metrics
endpoints:
  - port: http
    path: /health
    interval: 5s
```

## 🔄 CI/CD Pipeline

The GitHub Actions workflow automates the entire deployment process:

### Pipeline Stages

1. **Unit Testing**
   - Multi-version Python testing (3.8, 3.9, 3.10)
   - Multi-OS testing (Ubuntu, macOS)
   - Pytest execution with error handling

2. **Code Coverage**
   - Coverage analysis with pytest-cov
   - HTML and XML reports generation

3. **Containerization**
   - Docker image building
   - Multi-registry push (Docker Hub + GHCR)
   - Image testing and validation

4. **Infrastructure Deployment**
   - Terraform plan and apply
   - AWS EKS cluster provisioning

5. **Application Deployment**
   - Kubernetes deployment
   - Service configuration
   - Health verification

6. **Monitoring Setup**
   - Prometheus and Grafana deployment
   - Custom metrics configuration
   - Dashboard setup

### Workflow Triggers
- Push to `main` branch
- Manual workflow dispatch
- Pull request (testing only)

## ⚙️ Configuration

### Environment Variables

| Variable | Description | Required | Default |
|----------|-------------|----------|---------|
| `MONGO_URI` | MongoDB connection string | Yes | `mongodb://localhost:27017/` |
| `MONGO_USERNAME` | MongoDB username | No | - |
| `MONGO_PASSWORD` | MongoDB password | No | - |
| `GRAFANA_ADMIN_PASSWORD` | Grafana admin password | Yes | - |

### GitHub Secrets

Configure these secrets in your GitHub repository:

```bash
AWS_ACCESS_KEY_ID          # AWS access key for Terraform and kubectl
AWS_SECRET_ACCESS_KEY      # AWS secret key
DOCKERHUB_USERNAME         # Docker Hub username
DOCKERHUB_PASSWORD         # Docker Hub password/token
MONGO_PASSWORD            # MongoDB password
GRAFANA_ADMIN_PASSWORD    # Grafana admin interface password
```

### GitHub Variables

```bash
DOCKERHUB_USERNAME        # Docker Hub username (public)
MONGO_USERNAME           # MongoDB username (public)
```

## 🐛 Troubleshooting

### Common Issues

**MongoDB Connection Issues**
```bash
# Check if MongoDB service is running
kubectl get pods | grep mongodb
kubectl logs deployment/mongodb

# Verify connection string
kubectl exec -it deployment/flask-microservice -- env | grep MONGO
```

**EKS Access Issues**
```bash
# Update kubeconfig
aws eks --region us-east-1 update-kubeconfig --name sprints-cluster-0

# Check cluster status
kubectl cluster-info
kubectl get nodes
```

**LoadBalancer Pending**
```bash
# Check service status
kubectl get svc -o wide
kubectl describe svc flask-microservice-service

# Check AWS Load Balancer Controller
kubectl get pods -n kube-system | grep aws-load-balancer
```

**Prometheus Not Loading**
```bash
# Check monitoring namespace
kubectl -n monitoring get all

# Verify service names
kubectl -n monitoring get svc | grep prometheus

# Check LoadBalancer status
kubectl -n monitoring describe svc kube-prometheus-stack-kube-prom-prometheus
```

### Debug Commands

```bash
# Application logs
kubectl logs deployment/flask-microservice -f

# MongoDB logs
kubectl logs deployment/mongodb -f

# Monitoring logs
kubectl -n monitoring logs deployment/kube-prometheus-stack-prometheus-operator

# Check resource usage
kubectl top nodes
kubectl top pods
```

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Make your changes
4. Add tests for new functionality
5. Ensure all tests pass (`pytest`)
6. Update documentation if needed
7. Commit your changes (`git commit -m 'Add amazing feature'`)
8. Push to the branch (`git push origin feature/amazing-feature`)
9. Open a Pull Request


## 📚 Additional Resources

- [Flask Documentation](https://flask.palletsprojects.com/)
- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [Prometheus Documentation](https://prometheus.io/docs/)
- [Grafana Documentation](https://grafana.com/docs/)

---

**Built with ❤️ using Flask, Kubernetes, and modern DevOps practices**