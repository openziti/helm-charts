This helm chart is designed to deploy the zitified version of prometheus

A ziti identity for the prometheus server is required as part of the deployment in order to scrape targets over ziti

-----------------------

Configuring the chart

======================

By default the deployment sets up some scrape targets to scrape the system that prometheus server is deployed on. In order to scrape additional targets one of two methods can be used:


-----------------------------------------------
Editing the prometheus.yaml file once deployed:
-----------------------------------------------
jobs can be added to the prometheus.yaml after the service is deployed by running

kubectl edit cm prometheus-server

this opens a text editor that will allow you to modify the config map for the prometheus-server which contains the prometheus.yaml file. From here new jobs can be added. The pod should restart automatically


----------------------------------------
Deploying additional targets on install:
----------------------------------------
create a YAML file that will contain your additional scrape targets. the YAML file will look something like:

- job_name: 'job1'
  scrape_interval: 15s
  honor_labels: true
  scheme: 'ziti'
  params:
  'match[]':
  - '{job!=""}'
  'ziti-config':
  - '/etc/prometheus/{identityFileName}.json'
  static_configs:
    - targets:
        - '{serviceName}-{identityFileName}'

- job_name: 'job2'
  scrape_interval: 15s
  honor_labels: true
  scheme: 'ziti'
  params:
  'match[]':
  - '{job!=""}'
  'ziti-config':
  - '/etc/prometheus/{prometheusIdentityName}.json'

  static_configs:
    - targets:
        - '{serviceName}-{targetIdentityName}'

With the YAML file containing your additional targets, add the following arugment to your install command:

--set-file extraScrapeConfigs=myScrapeConfigs.yaml

where myScrapeConfigs.yaml is the path to the yaml containing the extra scrape configs

This method can also be used when updating scrape targets by running a helm update instead of an install


-----------------------------
Configuring the identity file
-----------------------------
The ziti identity json file must be provided during an install/updgrade in order to scrape ziti targets. This can be done by the use of the following arugment

--set-file prometheusIdentity=prometheus.json

where prometheus.json is the path to the identity file on the local machine.

By default, this helm chart will mount this file to /etc/prometheus/prometheus.json on the kubernetes cluster. Please take care to include the full path when providing your scrape targets


---------------------------------------
Changing the mounted identity file name
---------------------------------------
It is possible to change the name of the identity file that gets mounted on the kubernetes cluster if the prometheus.json identity name isn't desired. This can be done with the following argument:

--set identityFileName=myIdentity

where myIdentity is the name of the identity. This will cause the identity file to be mounted at /etc/prometheus/myIdentity.json instead of /etc/prometheus/prometheus.json


-----------------------------------------------------------------------------------------------------------------------------------

Example Installation Command

Assume that we have an identity file zitiPrometheus.json and we have a yaml file called zitiTargets.yaml which contains the following:



- job_name: 'redis'
  scrape_interval: 15s
  honor_labels: true
  scheme: 'ziti'
  params:
  'match[]':
  - '{job!=""}'
  'ziti-config':
  - '/etc/prometheus/prometheus.json'
  static_configs:
    - targets:
        - 'metrics-minikube'

- job_name: 'traefik'
  scrape_interval: 15s
  honor_labels: true
  scheme: 'ziti'
  params:
  'match[]':
  - '{job!=""}'
  'ziti-config':
  - '/etc/prometheus/prometheus.json'

  static_configs:
    - targets:
        - 'traefikPrometheus-prometheus'




The following command will allow us to install zitified prometheus:
// TODO update once remote
helm install prometheus . --set-file prometheusIdentity=zitiPrometheus.json --set-file extraScrapeConfigs=zitiTargets.yaml


**NOTE: since we did not provide an identityFileName the identity file is mounted as /etc/prometheus/prometheus.json by default

--------------------------

If we wanted to specify the identity file name to match the local identity file's name we would first change

/etc/prometheus/prometheus.json

to

/etc/prometheus/zitiPrometheus.json


in our zitiTargets.yaml file

the helm command would then look like:

helm install prometheus . --set-file prometheusIdentity=zitiPrometheus.json --set-file extraScrapeConfigs=zitiTargets.yaml --set identityFileName=zitiPrometheus

--------------------
Upgrading the Chart
--------------------

If we needed to add a new job to our zitiTargets we could either run

kubectl edit cm prometheus-server

to add the targets directly to the config map


Otherwise, we would run the same command as we did earlier except run a upgrade instead of an install. So for the case where the identityFileName was set it would look like:

helm upgrade prometheus . --set-file prometheusIdentity=zitiPrometheus.json --set-file extraScrapeConfigs=zitiTargets.yaml --set identityFileName=zitiPrometheus
kubectl scale deployment prometheus-server --replicas=0
kubectl scale deployment prometheus-server --replicas=1

by scaling the deployment down and then up this will force a restart so that the new scrapes get picked up

