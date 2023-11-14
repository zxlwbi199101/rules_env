load("@rules_rust//rust:defs.bzl", "rust_binary")
load("@crate_index//:defs.bzl", "aliases", "all_crate_deps")

package(default_visibility = ["//visibility:public"])

rust_binary(
    name = "env_compiler",
    srcs = ["compiler/main.rs"],
    edition = "2021",
    proc_macro_deps = [
        # "@crate_index//:clap",
    ],
    deps = [
        "@crate_index//:base64",
        "@crate_index//:clap",
        "@crate_index//:dotenv-parser",
        "@crate_index//:home",
        "@crate_index//:rust-crypto",
    ],
)
