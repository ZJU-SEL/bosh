# BOSH [![Build Status](https://travis-ci.org/cloudfoundry/bosh.png?branch=master)](https://travis-ci.org/cloudfoundry/bosh) [![Code Climate](https://codeclimate.com/github/cloudfoundry/bosh.png)](https://codeclimate.com/github/cloudfoundry/bosh)

# NOTE

We are now working with NTT guys to co-develop the new version of BOSH CloudStack CPI, see:
[https://github.com/cloudfoundry-community/bosh-cloudstack-cpi](https://github.com/cloudfoundry-community/bosh-cloudstack-cpi)

So the newest code of CPI has been moved to that repo!

But if you want to try the old version of CPI from ZJU-SEL, be free to checkout the stable zju-dev branch.
The old version of CPI is more like OpenStack CPI style while the new co-operated version is like AWS style. The more detailed diff is in this wiki: [https://github.com/cloudfoundry-community/bosh-cloudstack-cpi/wiki/Difference-between-ZJU-SEL-and-NTT-implementations] (https://github.com/cloudfoundry-community/bosh-cloudstack-cpi/wiki/Difference-between-ZJU-SEL-and-NTT-implementations)

# Using Cloud Foundry with Cloud Stack by CPI

This is the alpha release of BOSH with Cloud Stack CPI supported. This project is owned by SEL (Software Engineering Lab) of ZJU.

Branchs:
- master: exactly same with Cloud Foundry BOSH
- zjudev: the main branch of our project

Cloud Stack Stemcell:
- see:  [https://github.com/ZJU-SEL/bosh_cloudstack_stemcell](http://github.com/ZJU-SEL/bosh_cloudstack_stemcell/)

The Cloud Stack CPI has been well tested on:
- Cloud Stack 4.0
- cf-release 128.1
- BOSH stuff 1.5.0-pre2

Besides the CPI part, we did some modifiy in:

bosh/bosh_agent/lib/bosh_agent/infrastructure/cloudstack
bosh/bosh_cloudstack_registry
bosh/bosh_deployer/lib/deployer/instance_manager/cloudstack.rb

And we also added a lot of features to "fog", see:  [http://github.com/ZJU-SEL/fog/](http://github.com/ZJU-SEL/fog/)

NOTE: You have to use our own fog version for now (by pre-install our fog in your gem env and re-config Gemfile), but we'll solve this problem in next step soon.


#TODO
Our next step will be:
- merge part of the code to Cloud Foundry BOSH by sending PR
- commit our fog to https://github.com/fog/fog by sending PR

Be free to enjoy it!

Cloud Foundry BOSH is an open source tool chain for release engineering, deployment and lifecycle management of large scale distributed services. In this manual we describe the architecture, topology, configuration, and use of BOSH, as well as the structure and conventions used in packaging and deployment.

* BOSH Documentation: [http://cloudfoundry.github.com/docs/running/deploying-cf/](http://cloudfoundry.github.com/docs/running/deploying-cf/)

# Cloud Foundry Resources #

_Cloud Foundry Open Source Platform as a Service_

## Learn

Our documentation, currently a work in progress, is available here: [http://cloudfoundry.github.com/](http://cloudfoundry.github.com/)

## Ask Questions

Questions about the Cloud Foundry Open Source Project can be directed to our Google Groups.

* BOSH Developers: [https://groups.google.com/a/cloudfoundry.org/group/bosh-dev/topics](https://groups.google.com/a/cloudfoundry.org/group/bosh-dev/topics)
* BOSH Users:[https://groups.google.com/a/cloudfoundry.org/group/bosh-users/topics](https://groups.google.com/a/cloudfoundry.org/group/bosh-users/topics)
* VCAP (Cloud Foundry) Developers: [https://groups.google.com/a/cloudfoundry.org/group/vcap-dev/topics](https://groups.google.com/a/cloudfoundry.org/group/vcap-dev/topics)

## File a bug

Bugs can be filed using Github Issues within the various repositories of the [Cloud Foundry](http://github.com/cloudfoundry) components.

## OSS Contributions

The Cloud Foundry team uses GitHub and accepts contributions via [pull request](https://help.github.com/articles/using-pull-requests)

Follow these steps to make a contribution to any of our open source repositories:

1. Complete our CLA Agreement for [individuals](http://www.cloudfoundry.org/individualcontribution.pdf) or [corporations](http://www.cloudfoundry.org/corpcontribution.pdf)
1. Set your name and email

		git config --global user.name "Firstname Lastname"
		git config --global user.email "your_email@youremail.com"

Fork the BOSH repo

Make your changes on a topic branch, commit, and push to github and open a pull request.

Once your commits are approved by Travis CI and reviewed by the core team, they will be merged.
