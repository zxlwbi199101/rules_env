def _impl(ctx):
    # The list of arguments we pass to the script.
    # args = [ctx.outputs.out.path] + [f.path for f in ctx.files.chunks]
    args = ["--env", "test", "compile", "-o", ctx.outputs.out.path]

    for f in ctx.files.envs:
        args = args + ["-i", f.path]
        print("collect", f.path)

    ctx.actions.run(
        inputs = ctx.files.envs,
        outputs = [ctx.outputs.out],
        arguments = args,
        progress_message = "Merging into %s" % ctx.outputs.out.short_path,
        executable = ctx.executable.env_compiler,
        # output = ctx.outputs.out,
        # content = "\n".join(content),
    )

    # Action to call the script.
    ctx.actions.run(
        inputs = ctx.files.envs,
        outputs = [ctx.outputs.out],
        arguments = args,
        progress_message = "Merging into %s" % ctx.outputs.out.short_path,
        executable = ctx.executable.env_compiler,
    )

compile_env = rule(
    implementation = _impl,
    attrs = {
        "envs": attr.label_list(allow_files = True),
        "out": attr.output(),
        "env_compiler": attr.label(
            executable = True,
            cfg = "exec",
            allow_files = True,
            default = Label("//tools/rules_env:env_compiler"),
        ),
    },
)
