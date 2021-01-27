local ku = import 'kubeutil.libsonnet';

{
  task::
    local kind = { apiVersion: 'tekton.dev/v1beta1', kind: 'Task' };
    {
      new(name):: kind + ku.metaMixin({ name: name }),
      step(name, image):: { name: name, image: image },
    },

  taskRun::
    local kind = { apiVersion: 'tekton.dev/v1beta1', kind: 'TaskRun' };
    {
      new(name, serviceAccountName='default', generate=false)::
        kind
        + ku.metaMixin(if (generate) then { generateName: name } else { name: name })
        + ku.specMixin({ serviceAccountName: serviceAccountName }),
    },

  pipeline::
    local kind = { apiVersion: 'tekton.dev/v1beta1', kind: 'Pipeline' };
    {
      new(name):: kind + ku.metaMixin({ name: name }),
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
    local kind = { apiVersion: 'tekton.dev/v1beta1', kind: 'PipelineRun' };
    {
      new(name, serviceAccountName='default', generate=false)::
        kind
        + ku.metaMixin(if (generate) then { generateName: name } else { name: name })
        + ku.specMixin({ serviceAccountName: serviceAccountName }),
    },
}
