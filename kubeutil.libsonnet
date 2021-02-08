local k = import 'github.com/jsonnet-libs/k8s-alpha/1.18/main.libsonnet';
{
  metaMixin(meta):: { metadata+: meta },
  specMixin(spec):: { spec+: spec },

  withOwnerReferences(owners):: self.metaMixin({ ownerReferences+: if std.isArray(owners) then owners else [owners] }),

  // configMapVolumeMount adds a configMap to deployment-like objects.
  // It will also add an annotation hash to ensure the pods are re-deployed
  // when the config map changes.
  configMapVolumeMount(configMap, path, volumeMountMixin={})::
    local name = configMap.metadata.name,
          hash = std.md5(std.toString(configMap)),
          container = k.core.v1.container,
          deployment = k.apps.v1.deployment,
          volumeMount = k.core.v1.volumeMount,
          volume = k.core.v1.volume,
          addMount(c) = c + container.withVolumeMountsMixin(volumeMount.new(name, path) + volumeMountMixin);

    deployment.mapContainers(addMount) +
    deployment.spec.template.spec.withVolumesMixin([volume.fromConfigMap(name, name)]) +
    deployment.spec.template.metadata.withAnnotationsMixin({ ['%s-hash' % name]: hash }),

  // VolumeMount helper functions can be augmented with mixins.
  // For example, passing "volumeMount.withSubPath(subpath)" will result in
  // a subpath mixin.
  configVolumeMount(name, path, volumeMountMixin={})::
    local container = k.core.v1.container,
          deployment = k.apps.v1.deployment,
          volumeMount = k.core.v1.volumeMount,
          volume = k.core.v1.volume,
          addMount(c) = c + container.withVolumeMountsMixin(volumeMount.new(name, path) + volumeMountMixin);

    deployment.mapContainers(addMount) +
    deployment.spec.template.spec.withVolumesMixin([volume.fromConfigMap(name, name)]),

  hostVolumeMount(name, hostPath, path, readOnly=false, volumeMountMixin={})::
    local container = k.core.v1.container,
          deployment = k.apps.v1.deployment,
          volumeMount = k.core.v1.volumeMount,
          volume = k.core.v1.volume,
          addMount(c) = c + container.withVolumeMountsMixin(volumeMount.new(name, path, readOnly=readOnly) + volumeMountMixin);

    deployment.mapContainers(addMount) +
    deployment.spec.template.spec.withVolumesMixin([volume.fromHostPath(name, hostPath)]),

  secretVolumeMount(name, path, defaultMode=256, volumeMountMixin={})::
    local container = k.core.v1.container,
          deployment = k.apps.v1.deployment,
          volumeMount = k.core.v1.volumeMount,
          volume = k.core.v1.volume,
          addMount(c) = c + container.withVolumeMountsMixin(volumeMount.new(name, path) + volumeMountMixin);

    deployment.mapContainers(addMount) +
    deployment.spec.template.spec.withVolumesMixin([
      volume.fromSecret(name, secretName=name) +
      volume.secret.withDefaultMode(defaultMode),
    ]),

  emptyVolumeMount(name, path, volumeMountMixin={}, volumeMixin={})::
    local container = k.core.v1.container,
          deployment = k.apps.v1.deployment,
          volumeMount = k.core.v1.volumeMount,
          volume = k.core.v1.volume,
          addMount(c) = c + container.withVolumeMountsMixin(volumeMount.new(name, path) + volumeMountMixin);

    deployment.mapContainers(addMount) +
    deployment.spec.template.spec.withVolumesMixin([volume.fromEmptyDir(name) + volumeMixin]),

  antiAffinity:
    {
      local deployment = k.apps.v1.deployment,
      local podAntiAffinity = deployment.spec.template.spec.affinity.podAntiAffinity,
      local name = super.spec.template.metadata.labels.name,

      spec+: podAntiAffinity.withRequiredDuringSchedulingIgnoredDuringExecution([
        { topologyKey: 'kubernetes.io/hostname', labelSelector: { matchLabels: { name: name } } },
      ]).spec,
    },

}
