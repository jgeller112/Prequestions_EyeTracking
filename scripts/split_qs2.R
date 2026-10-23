# split_qs2.R
# Script to split large .qs2 files into chunks < 99 MB for GitHub upload,
# and helper function to recombine split files when needed.

#' Split a .qs2 file into parts smaller than max_size_mb
#' @param file_path Path to the .qs2 file
#' @param max_size_mb Maximum chunk size in megabytes (default: 90 MB)
split_qs2_file <- function(file_path, max_size_mb = 90) {
  if (!file.exists(file_path)) {
    warning(paste("File does not exist:", file_path))
    return(invisible(NULL))
  }

  file_size <- file.info(file_path)$size
  max_size_bytes <- max_size_mb * 1024 * 1024

  if (file_size <= max_size_bytes) {
    message(sprintf("File %s is %0.2f MB (<= %d MB), skipping split.", file_path, file_size / (1024 * 1024), max_size_mb))
    return(invisible(NULL))
  }

  message(sprintf("Splitting %s (%0.2f MB) into parts < %d MB...", file_path, file_size / (1024 * 1024), max_size_mb))

  con <- file(file_path, "rb")
  on.exit(close(con))

  part_num <- 1
  created_parts <- character(0)

  repeat {
    bytes <- readBin(con, "raw", n = max_size_bytes)
    if (length(bytes) == 0) break

    part_file <- sprintf("%s.part%03d", file_path, part_num)
    p_con <- file(part_file, "wb")
    writeBin(bytes, p_con)
    close(p_con)

    created_parts <- c(created_parts, part_file)
    part_num <- part_num + 1
  }

  message(sprintf("Successfully created %d parts for %s", length(created_parts), file_path))
  return(invisible(created_parts))
}

#' Combine split part files into a single file if needed
#' @param file_path Path to the target combined file (e.g. "Angele_et_al_2022/blmm_exp1_classical_rt.qs2")
combine_qs2_file <- function(file_path) {
  dir_name <- dirname(file_path)
  base_name <- basename(file_path)

  # Find matching part files: base_name.part001, base_name.part002, etc.
  all_files <- list.files(dir_name, full.names = TRUE)
  part_prefix <- paste0(base_name, ".part")
  parts <- all_files[startsWith(basename(all_files), part_prefix)]
  parts <- parts[grepl("\\.part[0-9]+$", parts)]

  if (length(parts) == 0) {
    return(FALSE)
  }

  parts <- sort(parts)
  parts_total_size <- sum(file.info(parts)$size)

  # If the combined file already exists and its size matches sum of parts, no need to recombine
  if (file.exists(file_path)) {
    if (file.info(file_path)$size == parts_total_size) {
      return(TRUE)
    }
  }

  message(sprintf("Combining %d parts into %s (%0.2f MB)...", length(parts), file_path, parts_total_size / (1024 * 1024)))

  out_con <- file(file_path, "wb")
  on.exit(close(out_con))

  for (part in parts) {
    p_size <- file.info(part)$size
    p_con <- file(part, "rb")
    bytes <- readBin(p_con, "raw", n = p_size)
    close(p_con)
    writeBin(bytes, out_con)
  }

  message(sprintf("Successfully combined %s", file_path))
  return(TRUE)
}

#' Check all split part files in a root directory and recombine any missing combined files
#' @param root_dir Directory to search for .qs2.part* files (default: ".")
check_and_combine_qs2 <- function(root_dir = ".") {
  all_parts <- list.files(root_dir, pattern = "\\.qs2\\.part[0-9]+$", recursive = TRUE, full.names = TRUE)
  if (length(all_parts) == 0) {
    return(invisible(NULL))
  }

  # Derive original target files by removing .partXXX
  qs2_targets <- unique(sub("\\.part[0-9]+$", "", all_parts))
  for (target in qs2_targets) {
    combine_qs2_file(target)
  }
  return(invisible(qs2_targets))
}

# If run as a standalone script (e.g. via Rscript split_qs2.R):
if (!interactive() && sys.nframe() == 0) {
  args <- commandArgs(trailingOnly = TRUE)
  if (length(args) > 0) {
    files_to_split <- args
  } else {
    files_to_split <- list.files(here::here(), pattern = "\\.qs2$", recursive = TRUE, full.names = TRUE)
  }

  if (length(files_to_split) == 0) {
    cat("No .qs2 files found to split.\n")
  } else {
    for (f in files_to_split) {
      # Skip part files if any matched
      if (grepl("\\.part[0-9]+$", f)) next
      split_qs2_file(f, max_size_mb = 90)
    }
  }
}
