EnvSources = provider("files")

def _impl(ctx):
    # in_files = ctx.file.src
    out_file = ctx.actions.declare_file("%s.bzlenv" % ctx.attr.name)

    in_files = depset(
        [ctx.file.src],
        transitive = [dep[EnvSources].files for dep in ctx.attr.deps],
    )

    print("sources: ", in_files)

    # Action to call the script.、
    # ctx.actions.run(
    #     inputs = input_src,
    #     outputs = outputs,
    #     arguments = [args],
    #     progress_message = "Generating enums for %s" % ctx.file.values_file.short_path,
    #     executable = ctx.executable.gen_tool,
    # )

    ctx.actions.run_shell(
        # Input files visible to the action.
        inputs = [ctx.file.src],
        # Output files that must be created by the action.
        outputs = [out_file],
        # The progress message uses `short_path` (the workspace-relative path)
        # since that's most meaningful to the user. It omits details from the
        # full path that would help distinguish whether the file is a source
        # file or generated, and (if generated) what configuration it is built
        # for.
        progress_message = "generate env file %s" % ctx.file.src.path,
        # The command to run. Alternatively we could use '$1', '$2', etc., and
        # pass the values for their expansion to `run_shell`'s `arguments`
        # param (see convert_to_uppercase below). This would be more robust
        # against escaping issues. Note that actions require the full `path`,
        # not the ambiguous truncated `short_path`.
        command = "cp %s %s" % (ctx.file.src.path, out_file.path),
    )

    return [
        EnvSources(files = in_files),
        DefaultInfo(files = depset([out_file])),
    ]

env_library = rule(
    implementation = _impl,
    attrs = {
        "src": attr.label(
            allow_single_file = True,
            mandatory = True,
        ),
        "deps": attr.label_list(allow_files = False),
    },
)
