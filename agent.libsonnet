local k = import 'github.com/jsonnet-libs/k8s-alpha/1.18/main.libsonnet';
local ku = import 'kubeutil.libsonnet';

local container = k.core.v1.container;
local defaultResources =
  container.resources.withRequests({ cpu: '500m', memory: '512Mi' })
  + container.resources.withLimits({ cpu: '8', memory: '16Gi' });

{

  node(
    name,
    publicKey,
    privateKey,
    serviceAccountName='default',
    resources=defaultResources,
    nodeAffinity=null,
    externalPorts=[],
    internalPorts=[],
    image='zyguan/ssh-agent:base',
    imagePullPolicy='IfNotPresent',
  )::
    self.cluster(
      name,
      publicKey,
      privateKey,
      controlServiceAccountName=serviceAccountName,
      controlResources=resources,
      nodes=0,
      nodeAffinity=nodeAffinity,
      externalPorts=externalPorts,
      internalPorts=internalPorts,
      image=image,
      imagePullPolicy=imagePullPolicy,
    ),

  cluster(
    name,
    publicKey,
    privateKey,
    controlServiceAccountName='default',
    controlResources=defaultResources,
    nodes=3,
    nodeServiceAccountName='default',
    nodeResources=defaultResources,
    nodeAffinity=null,
    storageClass=null,
    externalPorts=[],
    internalPorts=[],
    image='zyguan/ssh-agent:base',
    imagePullPolicy='IfNotPresent',
  )::
    local controlSuffix = if (nodes == 0) then '' else '-control';
    {
      info:
        k.core.v1.secret.new(name + '-info', {
          name: std.base64(name),
          private_key: std.base64(privateKey),
          cluster: std.base64(std.manifestJsonEx({
            control: '%(name)s%(suffix)s-0.%(name)s%(suffix)s-peer' % { name: name, suffix: controlSuffix },
            nodes: [
              '%(name)s-node-%(num)d.%(name)s-node-peer' % { name: name, num: i }
              for i in std.range(0, nodes - 1)
            ],
          }, '  ') + '\n'),
        }),

      control:
        local ss = k.apps.v1.statefulSet,
              pvc = k.core.v1.persistentVolumeClaim;
        ss.new(name + controlSuffix, 1, [
          container.new('agent', image)
          + controlResources {
            imagePullPolicy: imagePullPolicy,
            env: [{ name: 'AUTHORIZED_KEYS', value: publicKey }],
            ports: [{ name: 'ssh', containerPort: 22 }],
            volumeMounts: [{ name: 'data', mountPath: '/data' }],
          },
        ], [
          pvc.new('data')
          + pvc.spec.withAccessModes(['ReadWriteOnce'])
          + pvc.spec.resources.withRequests({ storage: '10G' })
          + if (storageClass != null) then pvc.spec.withStorageClassName(storageClass) else {},
        ])
        + ss.spec.withServiceName(self.controlPeerService.metadata.name)
        + ss.spec.template.spec.withServiceAccountName(controlServiceAccountName)
        + ku.hostVolumeMount('cgroup', '/sys/fs/cgroup', '/sys/fs/cgroup', true)
        + ku.emptyVolumeMount('run', '/run', volumeMixin={ emptyDir: { medium: 'Memory' } })
        + ku.secretVolumeMount(self.info.metadata.name, '/root/info')
        + if (nodeAffinity != null) then nodeAffinity else {},

      controlService:
        local port = k.core.v1.servicePort,
              svc = k.core.v1.service;
        svc.new(name + controlSuffix, self.control.spec.selector.matchLabels, [
          port.newNamed('external-%d' % p, p, p)
          for p in [22] + externalPorts
        ])
        + svc.spec.withType('NodePort'),

      controlPeerService:
        local port = k.core.v1.servicePort,
              svc = k.core.v1.service;
        svc.new(name + controlSuffix + '-peer', self.control.spec.selector.matchLabels, [
          port.newNamed('internal-%d' % p, p, p)
          for p in [22] + internalPorts
        ])
        + svc.spec.withClusterIP('None'),

      node:
        local ss = k.apps.v1.statefulSet,
              pvc = k.core.v1.persistentVolumeClaim;
        if nodes > 0 then
          ss.new(name + '-node', 1, [
            container.new('agent', image)
            + nodeResources {
              imagePullPolicy: imagePullPolicy,
              env: [{ name: 'AUTHORIZED_KEYS', value: publicKey }],
              ports: [{ name: 'ssh', containerPort: 22 }],
              volumeMounts: [{ name: 'data', mountPath: '/data' }],
            },
          ], [
            pvc.new('data')
            + pvc.spec.withAccessModes(['ReadWriteOnce'])
            + pvc.spec.resources.withRequests({ storage: '40G' })
            + if (storageClass != null) then pvc.spec.withStorageClassName(storageClass) else {},
          ])
          + ss.spec.withServiceName(self.nodePeerService.metadata.name)
          + ku.hostVolumeMount('cgroup', '/sys/fs/cgroup', '/sys/fs/cgroup', true)
          + ku.emptyVolumeMount('run', '/run', volumeMixin={ emptyDir: { medium: 'Memory' } })
          + ku.secretVolumeMount(self.info.metadata.name, '/root/info')
          + ku.antiAffinity
          + if (nodeAffinity != null) then nodeAffinity else {},

      nodePeerService:
        local port = k.core.v1.servicePort,
              svc = k.core.v1.service;
        if nodes > 0 then
          svc.new(name + '-node-peer', self.control.spec.selector.matchLabels, [
            port.newNamed('internal-%d' % p, p, p)
            for p in [22] + internalPorts
          ])
          + svc.spec.withClusterIP('None'),
    },

}
