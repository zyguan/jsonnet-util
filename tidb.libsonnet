local ku = import 'kubeutil.libsonnet';

local default = {
  apiVersion: 'pingcap.com/v1alpha1',
  kind: 'TidbCluster',
  spec: {
    schedulerName: 'tidb-scheduler',
    imagePullPolicy: 'Always',
    pvReclaimPolicy: 'Delete',
    pd: {
      replicas: 1,
      config: {},
      requests: { storage: '10Gi', cpu: '250m', memory: '256Mi' },
      limits: { cpu: '4', memory: '8Gi' },
    },
    tikv: {
      replicas: 1,
      config: {},
      requests: { storage: '40Gi', cpu: '500m', memory: '1Gi' },
      limits: { cpu: '8', memory: '16Gi' },
    },
    tidb: {
      replicas: 1,
      config: {},
      service: { type: 'NodePort' },
      requests: { cpu: '500m', memory: '512Mi' },
      limits: { cpu: '8', memory: '16Gi' },
    },
    pump: {
      replicas: 0,
      // config: {},
      requests: { storage: '40Gi', cpu: '250m', memory: '256Mi' },
      limits: { cpu: '4', memory: '8Gi' },
    },
    ticdc: {
      replicas: 0,
      config: {},
      requests: { cpu: '250m', memory: '256Mi' },
      limits: { cpu: '4', memory: '8Gi' },
    },
    tiflash: {
      replicas: 0,
      config: {},
      storageClaims: [
        { resources: { requests: { storage: '40Gi' } } },
      ],
      requests: { cpu: '500m', memory: '1Gi' },
      limits: { cpu: '8', memory: '16Gi' },
    },
  },
};

{
  cluster::
    {
      local removeConfig(spec) = { [k]: spec[k] for k in std.objectFieldsAll(spec) if k != 'config' },

      new(name, version='latest', imageFrom='pingcap', withCDC=0, withPump=0, withTiFlash=0)::
        local c2i = {
          pd: 'pd',
          tikv: 'tikv',
          tidb: 'tidb',
          ticdc: 'ticdc',
          pump: 'tidb-binlog',
          tiflash: 'tiflash',
        };
        default
        { metadata: { name: name } }
        + { spec+: { [c]+: { image: '%s/%s:%s' % [imageFrom, c2i[c], version] } for c in std.objectFields(c2i) } }
        + (if withCDC > 0 then self.withCDCReplicas(withCDC) else {})
        + (if withPump > 0 then self.withPumpReplicas(withPump) else {})
        + (if withTiFlash > 0 then self.withFlashReplicas(withTiFlash) else {})
        + self.prune(),

      withDBReplicas(replicas):: self.withComponentMixin('tidb', { replicas: replicas }),
      withKVReplicas(replicas):: self.withComponentMixin('tikv', { replicas: replicas }),
      withPDReplicas(replicas):: self.withComponentMixin('pd', { replicas: replicas }),
      withCDCReplicas(replicas):: self.withComponentMixin('ticdc', { replicas: replicas }),
      withPumpReplicas(replicas):: self.withComponentMixin('pump', { replicas: replicas }),
      withFlashReplicas(replicas):: self.withComponentMixin('tiflash', { replicas: replicas }),

      withDBImage(image):: self.withComponentMixin('tidb', { image: image }),
      withKVImage(image):: self.withComponentMixin('tikv', { image: image }),
      withPDImage(image):: self.withComponentMixin('pd', { image: image }),
      withCDCImage(image):: self.withComponentMixin('ticdc', { image: image }),
      withPumpImage(image):: self.withComponentMixin('pump', { image: image }),
      withFlashImage(image):: self.withComponentMixin('tiflash', { image: image }),
      withHelperImage(image):: self.withComponentMixin('helper', { image: image }),

      withDBConfig(config):: self.withComponentMixin('tidb', { config: config }),
      withKVConfig(config):: self.withComponentMixin('tikv', { config: config }),
      withPDConfig(config):: self.withComponentMixin('pd', { config: config }),
      withCDCConfig(config):: self.withComponentMixin('ticdc', { config: config }),
      withPumpConfig(config):: self.withComponentMixin('pump', { config: config }),
      withFlashConfig(config):: self.withComponentMixin('tiflash', { config: config }),

      withComponentMixin(component, spec):: { spec+: { [component]+: spec } },

      prune()::
        {
          local spec = super.spec,
          local needPrune(val) = std.isObject(val) && std.objectHas(val, 'replicas') && val.replicas == 0,
          spec: {
            [key]: spec[key]
            for key in std.objectFields(spec)
            if !needPrune(spec[key])
          },
        },

      hasCustomConfig(configmap)::
        local cluster = configmap.metadata.labels['tidb/cluster'],
              component = configmap.metadata.labels['tidb/component'];
        {
          local spec = super.spec,
          local name = super.metadata.name,
          assert name == cluster : 'cluster name mismatch: %s <> %s' % [name, cluster],
          assert std.objectHas(spec, component) : 'no such component: %s' % component,
          spec+: {
            [component]: removeConfig(spec[component]),
          },
        },

      newCustomConfig(cluster, component, config)::
        {
          apiVersion: 'v1',
          kind: 'ConfigMap',
          data: {
            'config-file': config,
            'startup-script':
              if component == 'pd' then
                importstr 'manifests/tc_start_pd.sh'
              else if component == 'tikv' then
                importstr 'manifests/tc_start_kv.sh'
              else if component == 'tidb' then
                importstr 'manifests/tc_start_db.sh'
              else
                error 'unsupported component: %s' % component,
          },
        }
        + ku.metaMixin({
          name: '%s-%s' % [cluster, component],
          labels: { 'tidb/cluster': cluster, 'tidb/component': component },
        }),
    },
}
