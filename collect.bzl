"""Example of using an aspect to collect information from dependencies.

For more information about aspects, see the documentation:
  https://docs.bazel.build/versions/master/skylark/aspects.html
"""

EnvCollector = provider(
    fields = {"envs": "collected env files"},
)

def _env_collector_aspect_impl(_, ctx):
    # This function is executed for each dependency the aspect visits.

    # Collect files from the srcs
    env_files = []

    # if hasattr(ctx.rule.files, "data"):
    #     for f in ctx.rule.files.data:
    #         if f.extension == "bzlenv":
    #             env_files = env_files + [f]

    if hasattr(ctx.attr, "deps"):
        for i, d in enumerate(ctx.attr.deps):
            print(" {}. label = {}".format(i + 1, d.label))

            # A label can represent any number of files (possibly 0).
            print("    files = " + str([f.path for f in d.files.to_list()]))

    # if hasattr(ctx.rule.files, "deps"):
    #     for f in ctx.rule.files.deps:
    #         if f.extension == "bzlenv":
    #             env_files = env_files + [f]

    # if hasattr(ctx.rule.files, "outputs"):
    #     for f in ctx.rule.files.outputs:
    #         if f.extension == "bzlenv":
    #             env_files = env_files + [f]

    # if hasattr(ctx.rule.attr, "deps"):
    #     for dep in ctx.rule.attr.deps:
    #         env_files = env_files + [dep[EnvCollector].envs]

    # Combine direct files with the files from the dependencies.
    # transitive = []

    # if hasattr(ctx.rule.attr, "deps"):
    #     transitive = [dep[EnvCollector].envs for dep in ctx.rule.attr.deps]

    envs = depset(
        direct = env_files,
        transitive = [dep[EnvCollector].envs for dep in ctx.rule.attr.deps],
    )

    return [EnvCollector(envs = envs)]

env_collector_aspect = aspect(
    implementation = _env_collector_aspect_impl,
    attr_aspects = ["deps"],
)

def _env_collector_rule_impl(ctx):
    # This function is executed once per `env_collector`.
    all_input = []
    args = ["--env", "test", "compile", "-o", ctx.outputs.out.path]

    for dep in ctx.attr.deps:
        all_input += dep[EnvCollector].envs.to_list()
        # content.append("envs from {}: {}".format(dep.label, paths))

    # content.append("")  # trailing newline

    for input in all_input:
        args = args + ["-i", input.path]
        print("collect", input.path)

    ctx.actions.run(
        inputs = all_input,
        outputs = [ctx.outputs.out],
        arguments = args,
        progress_message = "Merging into %s" % ctx.outputs.out.short_path,
        executable = ctx.executable.env_compiler,
        # output = ctx.outputs.out,
        # content = "\n".join(content),
    )

_env_collector = rule(
    implementation = _env_collector_rule_impl,
    attrs = {
        "deps": attr.label_list(aspects = [env_collector_aspect]),
        "out": attr.output(),
        "env_compiler": attr.label(
            executable = True,
            cfg = "exec",
            allow_files = True,
            default = Label("//tools/rules_env:env_compiler"),
        ),
    },
)

def collect_env(**kwargs):
    _env_collector(out = ".env", **kwargs)
