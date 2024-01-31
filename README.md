# Fargate-PC-Console
Template to deploy Prisma Cloud console on AWS Fargate.

The following documentation contains two parts. The first part is deploying initial resources (ECS cluster, SG, EFS, Load Balancer). The second part for deploying Task Definition and Service.

Prequisitions: you should have permission to create Fargate resources in AWS + and Twistlock token. Please add your AWS credentials in the provider module.

**Creating initial resources:**  (lines 0-145)
1. In the main.tf file please change data for VPC and Subnets ID.
2. Run the script and wait until the resources will be created.

**Deploying Task Definition and Service.** ()
1. Go to line 145 and uncomment code.
2. Change the data to your VPC and SUBNET ID.
3. Generate the Task Definition json file using the following documentation and change the values in "container_definitions = jsonencode"  (https://docs.prismacloud.io/en/compute-edition/30/admin-guide/install/deploy-console/console-on-fargate#create-task-definition)
4. Apply script. (Bear in mind that the container needs an internet connection in order to pull images from the registry. Also you can provide the image localy. If you are getting the 'timeout' error during pulling the image, please fix the internet connection between the container and the registy. As a test you can add 0.0.0.0/0 network to the firewall and check if the timeout error still persists.)
  
**Log into Prisma Cloud Console**
Open a web browser and go to https://<Load balancer DNS name>:8083. Create an initial admin account, and then enter your license to activate Console.
