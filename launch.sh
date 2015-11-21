#!/bin/bash 

#creating instances with parameters
declare -a instance_id 
mapfile -t instance_id  < <(aws ec2 run-instances --image-id $1 --count $2 --instance-type $3 --key-name $4 --security-group-ids $5 --subnet-id $6 --associate-public-ip-address --iam-instance-profile Name=$7 --user-data file:///home/controller/Documents/MPFinal_Environment_Setup/install-webserver.sh --output table | grep InstanceId | sed "s/|//g" | tr -d ' ' | sed "s/InstanceId//g")
echo ${instance_id[@]} 
aws ec2 wait instance-running --instance-ids ${instance_id[@]}
aws elb create-load-balancer --load-balancer-name Project1 --listeners Protocol=HTTP,LoadBalancerPort=80,InstanceProtocol=HTTP,InstancePort=80 --security-groups $5 --subnets $6
aws elb register-instances-with-load-balancer --load-balancer-name Project1 --instances ${instance_id[@]}
aws elb configure-health-check --load-balancer-name Project1 --health-check Target=HTTP:80/index.html,Interval=30,UnhealthyThreshold=2,HealthyThreshold=2,Timeout=3
aws autoscaling create-launch-configuration --launch-configuration-name Project1-launch-config --image-id $1 --key-name $4 --security-groups $5 --instance-type $3 --user-data /home/controller/Documents/MPFinal_Environment_Setup/install-webserver.sh --iam-instance-profile $7
aws autoscaling create-auto-scaling-group --auto-scaling-group-name Project1-auto-scaling-group-2 --launch-configuration-name Project1-launch-config --load-balancer-names Project1 --health-check-type ELB --min-size 3 --max-size 6 --desired-capacity 3 --default-cooldown 600 --health-check-grace-period 120 --vpc-zone-identifier $6	
aws autoscaling put-scaling-policy --auto-scaling-group-name Project1-auto-scaling-group-2 --policy-name scalingpolicytest --scaling-adjustment 1 --adjustment-type ExactCapacity
aws cloudwatch put-metric-alarm --alarm-name Cloudwatchalarm --metric-name Cloudwatch --namespace AWS/EC2 --statistic Average --period 60 --threshold 30 --comparison-operator GreaterThanOrEqualToThreshold --dimensions "Name=AutoScalingGroup,Value=Project1-auto-scaling-group-2" --evaluation-periods 1 --alarm-actions arn:aws:autoscaling:us-west-2:089423386606:scalingPolicy:cc88d707-2094-4129-9525-f91079eec50f:autoScalingGroupName/Project1-auto-scaling-group-2:policyName/scalingpolicytest arn:aws:sns:us-west-2:089423386606:mp2
aws rds create-db-instance --db-name Project1db --db-instance-identifier Project1db --db-instance-class db.t2.micro --engine MySql --allocated-storage 20 --master-username nandini --master-user-password nandinipwd
aws rds create-db-instance-read-replica --db-instance-identifier Project1readonly --source-db-instance-identifier Project1db --db-instance-class db.t2.micro 
