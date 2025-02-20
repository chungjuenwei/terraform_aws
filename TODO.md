### To Do

1. Change the RDS password to tfvars? [DONE]


### Architecture
```
Internet
|
| (IGW)
|
VPC (10.0.0.0/16)
├── Public Subnets (10.0.1.0/24, 10.0.2.0/24) - For future web servers
└── Private Subnets (10.0.101.0/24, 10.0.102.0/24) - RDS Instance
    └── RDS MySQL
        ├── Security Group: Allows MySQL access from VPC
        └── db.t3.micro instance
```

### Prompt for learning how to do something

```
I want to learn how to use terraform to create an aws elastic transcoder resource

Can you help me generate a terraform script for an aws elastic transcoder resource, as well as accompanying scripts for a simple demo/learning exercise that i can see how this works?
```