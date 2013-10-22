  # CloudStack BOSH Cloud Provider Interface

[![Build Status](https://secure.travis-ci.org/piston/openstack-bosh-cpi.png)](http://travis-ci.org/piston/openstack-bosh-cpi)

## Bringing the world’s most popular open source platform-as-a-service to the world’s most stable open source infrastructure-as-a-service platform

This repo contains software designed to manage the deployment of Cloud Foundry on top of CloudStack, using Cloud Foundry BOSH.

## CloudStack
Apache CloudStack is open source software designed to deploy and manage large networks of virtual machines, as a highly available, highly scalable Infrastructure as a Service (IaaS) cloud computing platform. CloudStack is used by a number of service providers to offer public cloud services, and by many companies to provide an on-premises (private) cloud offering, or as part of a hybrid cloud solution.

CloudStack is a turnkey solution that includes the entire "stack" of features most organizations want with an IaaS cloud: compute orchestration, Network-as-a-Service, user and account management, a full and open native API, resource accounting, and a first-class User Interface (UI).

CloudStack currently supports the most popular hypervisors: VMware, KVM, XenServer and Xen Cloud Platform (XCP).

Users can manage their cloud with an easy to use Web interface, command line tools, and/or a full-featured RESTful API. In addition, CloudStack provides an API that's compatible with AWS EC2 and S3 for organizations that wish to deploy hybrid clouds.

## Cloud Foundry

Cloud Foundry is the leading open source platform-as-a-service (PaaS) offering with a fast growing ecosystem and strong enterprise demand.

## BOSH

Cloud Foundry BOSH is an open source tool chain for release engineering, deployment and lifecycle management of large scale distributed services. In this manual we describe the architecture, topology, configuration, and use of BOSH, as well as the structure and conventions used in packaging and deployment.

 * BOSH Source Code: https://github.com/cloudfoundry/bosh
 * BOSH Documentation: https://github.com/cloudfoundry/oss-docs/blob/master/bosh/documentation/documentation.md

## CloudStack and Cloud Foundry, Together using BOSH

Cloud Foundry BOSH defines a Cloud Provider Interface API that enables platform-as-a-service deployment across multiple cloud providers - initially VMWare's vSphere and AWS. ZJU-SEL Cloud has partnered with VMWare to provide a CPI for CloudStack, opening up Cloud Foundry deployment to an entire ecosystem of public and private CloudStack deployments.

Using a popular cloud-services client written in Ruby, the CloudStack CPI manages the deployment of a set of virtual machines and enables applications to be deployed dynamically using Cloud Foundry. A common image, called a stem-cell, allows Cloud Foundry BOSH to rapidly build new virtual machines enabling rapid scale-out.

We've partnered with VMWare to deliver this project, because the leading open-source platform-as-a-service offering should work seamlessly with deployments of the leading open-source infrastructure-as-a-service project. The work being done to develop this CPI, will enable customers of any CloudStack cloud to use Cloud Foundry to accelerate development of cloud applications and drive value by working against a common service API.

## Legal Stuff

This project, as well as CloudStack and Cloud Foundry, are Apache2-licensed Open Source.

VMware and Cloud Foundry are registered trademarks or trademarks of VMware, Inc. in the United States and/or other jurisdictions.

CloudStack is a registered trademark of CloudStack, LLC.
