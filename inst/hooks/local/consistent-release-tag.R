#!/usr/bin/env Rscript
"This hook checks that all versions in config files and the git tag that
 is used by precommit to clone the repo is identical.

Usage:
  consistent-release-tag [--release-mode] [<files>...]

" -> doc
arguments <- docopt::docopt(doc)


# This hook checks that all versions in config files and the git tag that
# is used by precommit to clone the repo is identical.
# DESCRIPTION is allowed to have higher version because the process is:
# - release a version e.g. 0.1.0 on CRAN, all example configs should match DESCRIPTION
# - continue development: Should bump DESCRIPTION to dev, e.g. 0.1.0.9000,
#   but not git tag or config examples. These should remain at 0.1.0.
# - release new version on CRAN, make sure all tags correspond to 0.2.0.

path_config <- c(
  fs::path("inst", "pre-commit-config-pkg.yaml"),
  fs::path("inst", "pre-commit-config-proj.yaml")
)



assert_config_has_rev <- function(path_config, latest_tag) {
  file <- yaml::read_yaml(path_config)
  repo <- purrr::map(file$repos, "repo")

  lorenzwalthert_precommit_idx <- which(repo == "https://github.com/lorenzwalthert/precommit")
  stopifnot(length(lorenzwalthert_precommit_idx) == 1)
  rev <- file$repos[[lorenzwalthert_precommit_idx]]$rev

  if (latest_tag != rev) {
    rlang::abort(glue::glue(
      "latest git tag is `{latest_tag}`, but in `{path_config}`, you the  ",
      "revision is set to `{rev}` Please make the two correspond."
    ))
  }
}

get_latest_tag <- function() {
  system2("git", c("fetch", "--tags"))
  system2("git", c("describe", "--tags", "--abbrev=0"), stdout = TRUE)
}

latest_tag <- get_latest_tag()

purrr::walk(path_config, assert_config_has_rev, latest_tag = latest_tag)
latest_tag_without_prefix <- gsub("^v", "", latest_tag)

if (!(latest_tag_without_prefix < desc::desc_get_field("Version"))) {
  if (latest_tag_without_prefix > desc::desc_get_field("Version")) {
    rlang::abort(paste(
      "git tag should never be greater than description. At most they should",
      "be equal."
    ))
  } else if (!arguments$release_mode) {
    rlang::abort(paste(
      "DESCRIPTION version must be larger than git tag unless the check is",
      " performed during a release. Then turn this off with --release-mode"
    ))
  }
}
