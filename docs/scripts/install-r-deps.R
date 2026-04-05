# Used by ../publish.sh --install-deps
# Prefers CRAN macOS .tgz binaries (CRAN’s .pkg R). Source fallback uses SDK from the shell.

cran_pkgs <- c("rmarkdown", "knitr", "distill", "postcards", "fontawesome")
repos <- getOption("repos")
if (length(repos) == 0 || identical(repos, c(CRAN = "@CRAN@"))) {
  repos <- c(CRAN = "https://cloud.r-project.org")
}

pkg_installed <- function(p) {
  nzchar(system.file(package = p))
}

is_mac <- grepl("darwin", R.version$os)
is_homebrew_r <- grepl("homebrew|Cellar", R.home(), ignore.case = TRUE)

if (is_mac) {
  message("Trying CRAN macOS binary packages (works with CRAN’s .pkg R, not Homebrew R)…")
  op <- options(install.packages.compile.from.source = "never")
  tryCatch(
    {
      suppressWarnings(install.packages(cran_pkgs, repos = repos, type = "binary"))
    },
    error = function(e) {
      message("Binary install not used: ", conditionMessage(e))
      if (is_homebrew_r) {
        message(
          "Homebrew R does not support CRAN’s type=\"binary\" (.tgz) installs; packages must compile from source",
          " unless you install CRAN’s R from https://cran.r-project.org/bin/macosx/ and put that Rscript first on PATH."
        )
      }
      message("Proceeding with source installs…\n")
    },
    finally = {
      options(op)
    }
  )
}

miss <- cran_pkgs[!vapply(cran_pkgs, pkg_installed, logical(1))]
if (length(miss)) {
  message(
    "Installing from source (needs Xcode Command Line Tools + working SDK): ",
    paste(miss, collapse = ", ")
  )
  install.packages(miss, repos = repos, type = "source")
}

still_cran <- cran_pkgs[!vapply(cran_pkgs, pkg_installed, logical(1))]
if (length(still_cran)) {
  message("\nCould not install: ", paste(still_cran, collapse = ", "))
  message(
    "\nIf you saw 'cstring' / 'cstdlib' file not found, your compiler cannot see the C++ standard library."
  )
  message("Try in order:")
  message("  1. xcode-select --install")
  message("  2. If Xcode.app is installed: sudo xcode-select -s /Applications/Xcode.app/Contents/Developer")
  message("  3. Best fix for ./publish.sh: install CRAN’s macOS R (.pkg), then either")
  message("       put /Library/Frameworks/R.framework/Resources/bin ahead of Homebrew on PATH,")
  message("       or edit publish.sh find_rscript() to prefer that path.")
  message("     https://cran.r-project.org/bin/macosx/")
  message("  4. Or build the site only in RStudio with the R version that already works there.\n")
  quit(save = "no", status = 1)
}

# pixture: not on CRAN; used in about.Rmd — R-universe binaries, then GitHub
install_pixture <- function() {
  if (pkg_installed("pixture")) {
    return(invisible(TRUE))
  }
  message("Installing pixture (About page gallery; from R-universe / GitHub, not CRAN)…")
  ru <- c(rfr = "https://royfrancis.r-universe.dev", CRAN = "https://cloud.r-project.org")

  if (is_mac) {
    op <- options(install.packages.compile.from.source = "never")
    tryCatch(
      suppressWarnings(install.packages("pixture", repos = ru, type = "binary")),
      error = function(e) message("(R-universe binary skipped) ", conditionMessage(e)),
      finally = {
        options(op)
      }
    )
  } else {
    tryCatch(
      install.packages("pixture", repos = ru, type = "source"),
      error = function(e) message(conditionMessage(e))
    )
  }

  if (!pkg_installed("pixture")) {
    message("Trying GitHub: royfrancis/pixture …")
    if (!pkg_installed("remotes")) {
      install.packages("remotes", repos = repos, type = if (is_mac) "binary" else "source")
    }
    remotes::install_github("royfrancis/pixture", upgrade = "never")
  }

  if (!pkg_installed("pixture")) {
    message("\nCould not install pixture.")
    message("The About page photo gallery needs it. Try in R:")
    message('  install.packages("pixture", repos = c("https://royfrancis.r-universe.dev", "https://cloud.r-project.org"))')
    message('  remotes::install_github("royfrancis/pixture")')
    quit(save = "no", status = 1)
  }
  invisible(TRUE)
}

install_pixture()

message("OK: site R packages are installed.")
