#!/usr/bin/env Rscript
# Emit JSON build info for R similar to other language tests

# R Build & Runtime Introspection -> JSON to stdout
# Emits JSON with R version, capabilities, external libs, compiler flags,
# BLAS/LAPACK, and detected optimizations.

#!/usr/bin/env Rscript

suppressWarnings(suppressMessages({
  have_jsonlite <- requireNamespace("jsonlite", quietly = TRUE)
}))

to_json <- function(x) {
  if (have_jsonlite) {
    jsonlite::toJSON(
      x,
      auto_unbox = TRUE,    # don't wrap scalars in arrays
      pretty = TRUE,        # human-readable formatting
      null = "null",
      na = "null"
    )
  } else {
    stop("Package 'jsonlite' is required for JSON output.")
  }
}

pick_makeconf <- function(lines, key) {
  i <- grep(paste0("^", key, "\\s*="), lines)
  if (length(i)) sub("^[^=]+=\\s*", "", lines[i[1]]) else NA_character_
}

detect_cpu_flags <- function(flags) {
  m <- regmatches(flags, gregexpr("\\-march=[^\\s]+|\\-mcpu=[^\\s]+|\\-mtune=[^\\s]+", flags))[[1]]
  if (length(m)) unique(m) else character()
}

read_makeconf <- function() {
  path <- file.path(R.home("etc"), "Makeconf")
  if (!file.exists(path)) return(list(path = NA_character_, present = FALSE))
  lines <- readLines(path, warn = FALSE)
  all_flags <- paste(na.omit(c(
    pick_makeconf(lines, "CFLAGS"),
    pick_makeconf(lines, "CXXFLAGS"),
    pick_makeconf(lines, "FFLAGS"),
    pick_makeconf(lines, "LDFLAGS"),
    pick_makeconf(lines, "SHLIB_LDFLAGS"),
    pick_makeconf(lines, "CPPFLAGS")
  )), collapse = " ")
  list(
    path = path,
    present = TRUE,
    CC = pick_makeconf(lines, "CC"),
    CFLAGS = pick_makeconf(lines, "CFLAGS"),
    CXX = pick_makeconf(lines, "CXX"),
    CXXFLAGS = pick_makeconf(lines, "CXXFLAGS"),
    FC = pick_makeconf(lines, "FC"),
    FFLAGS = pick_makeconf(lines, "FFLAGS"),
    LDFLAGS = pick_makeconf(lines, "LDFLAGS"),
    SHLIB_LDFLAGS = pick_makeconf(lines, "SHLIB_LDFLAGS"),
    CPPFLAGS = pick_makeconf(lines, "CPPFLAGS"),
    DETECTED = list(
      LTO = any(grepl("\\-flto(\\b|=)", all_flags)),
      CPUFlags = unname(detect_cpu_flags(all_flags)),
      OpenMP = isTRUE(unname(capabilities("openmp")))
    )
  )
}

rcmd_config <- function(keys) {
  out <- setNames(vector("list", length(keys)), keys)
  for (k in keys) {
    val <- tryCatch(system(paste("R CMD config", shQuote(k)), intern = TRUE),
                    error = function(e) NA_character_)
    if (length(val) == 0) val <- NA_character_
    out[[k]] <- paste(val, collapse = " ")
  }
  out
}

safe_capabilities <- function() {
  as.list(capabilities())
}

safe_extsoft <- function() {
  get_extsoft_fun <- function() {
    for (ns in c("grDevices", "utils", "base")) {
      nsobj <- tryCatch(asNamespace(ns), error = function(e) NULL)
      if (!is.null(nsobj) && exists("extSoftVersion", envir = nsobj, inherits = FALSE)) {
        return(get("extSoftVersion", envir = nsobj))
      }
    }
    ga <- suppressWarnings(getAnywhere("extSoftVersion"))
    if (!is.null(ga) && length(ga$objs) > 0) return(ga$objs[[1]])
    NULL
  }
  f <- get_extsoft_fun()
  if (is.null(f)) return(list(note = "extSoftVersion() not found"))
  ex <- tryCatch(f(), error = function(e) NULL)
  if (is.null(ex)) return(list(note = "extSoftVersion() call failed"))
  as.list(ex)
}

blas_lapack_info <- function() {
  env <- Sys.getenv(c(
    "R_BLAS", "R_LAPACK",
    "MKL_ROOT", "MKL_INTERFACE_LAYER", "MKL_THREADING_LAYER", "MKL_NUM_THREADS",
    "OPENBLAS_NUM_THREADS", "BLIS_NUM_THREADS", "OMP_NUM_THREADS"
  ), unset = NA_character_)
  si <- utils::sessionInfo()
  list(
    env = as.list(env),
    session = list(
      BLAS = tryCatch(unname(si$BLAS), error = function(e) NA_character_),
      LAPACK = tryCatch(unname(si$LAPACK), error = function(e) NA_character_)
    )
  )
}

compact_session_info <- function() {
  si <- utils::sessionInfo()
  attached <- character(0)
  if (!is.null(si$otherPkgs) && length(si$otherPkgs)) {
    attached <- vapply(si$otherPkgs,
                       function(p) paste0(p$Package, "@", p$Version),
                       character(1))
  }
  list(
    R = list(
      version = si$R.version$version.string,
      nickname = si$R.version$nickname,
      platform = si$R.version$platform
    ),
    running = si$running,
    matrixProducts = si$matrixProducts,
    locale = si$locale,
    basePkgs = si$basePkgs,        # <- leave as character vector
    loadedOnly = names(si$loadedOnly),
    attached = attached
  )
}

keys <- c("CC","CFLAGS","CXX","CXXFLAGS","FC","FFLAGS","LDFLAGS",
          "CPPFLAGS","SAFE_FFLAGS","SAFE_CFLAGS","SAFE_CXXFLAGS","SHLIB_LDFLAGS")

result <- list(
  timestamp = as.character(Sys.time()),
  platform = list(
    platform = R.version$platform,
    arch = R.version$arch,
    os = R.version$os,
    system = R.version$system,
    ui = .Platform$GUI,
    endian = .Platform$endian
  ),
  R = list(
    version = R.version$version.string,
    major = R.version$major,
    minor = R.version$minor,
    home = R.home(),
    session = compact_session_info()
  ),
  capabilities = safe_capabilities(),
  external_libraries = safe_extsoft(),
  blas_lapack = blas_lapack_info(),
  makeconf = read_makeconf(),
  r_cmd_config = rcmd_config(keys)
)

cat(to_json(result))
