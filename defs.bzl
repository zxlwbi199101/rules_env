def _impl(ctx):
    # The list of arguments we pass to the script.
    args = ["--env", ctx.attr.env_name, "compile", "-o", ctx.outputs.out.path]

    for f in ctx.files.envs:
        args = args + ["-i", f.path]
        print("collect", f.path)

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
        "envs": attr.label_list(allow_files = True, mandatory = True, allow_empty = False),
        "out": attr.output(),
        "env_name": attr.string(),
        "env_compiler": attr.label(
            executable = True,
            cfg = "exec",
            allow_files = True,
            default = Label("//tools/rules_env:env_compiler"),
        ),
    },
)

def get_env_from_config(names):
    return select({
        "//env:is_test": ["//env:test/" + n for n in names],
        "//env:is_gray": ["//env:gray/" + n for n in names],
        "//env:is_prod": ["//env:prod/" + n for n in names],
        "//conditions:default": ["//env:local/" + n for n in names],
    })

def get_env_name_from_config():
    return select({
        "//env:is_test": "test",
        "//env:is_gray": "gray",
        "//env:is_prod": "prod",
        "//conditions:default": "local",
    })

def env_library(name, envs):
    compile_env(
        name = name,
        envs = get_env_from_config(envs),
        env_name = get_env_name_from_config(),
        out = ".env",
    )
