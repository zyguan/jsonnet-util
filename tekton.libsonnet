local ku = import 'kubeutil.libsonnet';

{
  local type(kind) = { apiVersion: 'tekton.dev/v1beta1', kind: kind },

  task::
    {
      new(name):: type('Task') + ku.metaMixin({ name: name }),
      step(name, image):: { name: name, image: image },
    },

  taskRun::
    {
      new(name, serviceAccountName='default', generate=false)::
        type('TaskRun')
        + ku.metaMixin(if (generate) then { generateName: name } else { name: name })
        + ku.specMixin({ serviceAccountName: serviceAccountName }),
    },

  pipeline::
    {
      new(name):: type('Pipeline') + ku.metaMixin({ name: name }),
      task(name, taskRefName='', runAfter=[])::
        {
          name: name,
          taskRef: {
            name: if (std.length(taskRefName) == 0) then name else taskRefName,
          },
        }
        + (if (std.length(runAfter) == 0) then {} else { runAfter: runAfter }),
    },

  pipelineRun::
    {
      new(name, serviceAccountName='default', generate=false)::
        type('PipelineRun')
        + ku.metaMixin(if (generate) then { generateName: name } else { name: name })
        + ku.specMixin({ serviceAccountName: serviceAccountName }),
    },
}
