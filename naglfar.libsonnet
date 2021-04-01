local ku = import 'kubeutil.libsonnet';

{
  local type(kind) = { apiVersion: 'naglfar.pingcap.com/v1', kind: kind },

  testResourceRequest::
    {
      new(name, items=[], machines=[])::
        type('TestResourceRequest')
        + ku.metaMixin({ name: name })
        + ku.specMixin({ items: items, machines: machines }),

      machine(name, exclusive='false'):: {
        name: name,
        exclusive: exclusive,
      },

      item(name, coreNum, memory, disks={}, machine=null):: {
        name: name,
        spec: std.prune({
          cores: coreNum,
          memory: memory,
          disks: disks,
          machine: machine,
        }),
      },
    },

  testClusterTopology::
    {
      new(name, resourceRequest, version='nightly', control='control')::
        type('TestClusterTopology')
        + ku.metaMixin({ name: name })
        + ku.specMixin({
          resourceRequest: resourceRequest,
          tidbCluster: {
            version: { version: version },
            control: control,
          },
        }) + self,

      withPDConfig(config):: self.serverConfigMixin('pd', config),
      withDBConfig(config):: self.serverConfigMixin('tidb', config),
      withKVConfig(config):: self.serverConfigMixin('tikv', config),
      serverConfigMixin(name, config):: { spec+: { tidbCluster+: { serverConfigs+: {
        [name]: config,
      } } } },

      pdInstances(hosts, deployConfig):: self.instancesMixin('pd', hosts, deployConfig),
      dbInstances(hosts, deployConfig):: self.instancesMixin('tidb', hosts, deployConfig),
      kvInstances(hosts, deployConfig):: self.instancesMixin('tikv', hosts, deployConfig),
      monitorInstances(hosts, deployConfig):: self.instancesMixin('monitor', hosts, deployConfig),
      grafanaInstances(hosts, deployConfig):: self.instancesMixin('grafana', hosts, deployConfig),
      pumpInstances(hosts, deployConfig):: self.instancesMixin('pump', hosts, deployConfig),
      cdcInstances(hosts, deployConfig):: self.instancesMixin('cdc', hosts, deployConfig),
      tiflashInstances(hosts, deployConfig):: self.instancesMixin('tiflash', hosts, deployConfig),

      // instances with the same config but different hosts
      instancesMixin(component, hosts=[], config)::
        {
          spec+: {
            tidbCluster+: {
              [component]+: [config { host: h } for h in hosts],
            },
          },
        },
    },

  testWorkload:: {
    new(name)::
      type('TestWorkload')
      + ku.metaMixin({ name: name }),

    clusterTopologie(name, aliasName='standard'):: { spec+: { clusterTopologies+: [{
      name: name,
      aliasName: aliasName,
    }] } },

    workload(
      name,
      resourceRequest={ name: '', node: 'workload' },
      command=[],
      image='debian:buster',
      imagePullPolicy='IfNotPresent',
    ):: {
      spec+: {
        workloads+: [{
          name: name,
          dockerContainer: {
            resourceRequest: resourceRequest,
            image: image,
            imagePullPolicy: imagePullPolicy,
            command: command,
          },
        }],
      },
    },

  },
}
