# Older pkgdown releases request icon sizes absent from the upstream assets.
# Point those tags to the existing icons; no image or package code is changed.
fix_site_icons <- function(root) {
  docs <- file.path(root, "docs")
  replacements <- c("favicon-16x16.png"="favicon-96x96.png",
    "favicon-32x32.png"="favicon-96x96.png",
    "apple-touch-icon-120x120.png"="apple-touch-icon.png",
    "apple-touch-icon-76x76.png"="apple-touch-icon.png",
    "apple-touch-icon-60x60.png"="apple-touch-icon.png")
  stopifnot(all(file.exists(file.path(docs, unique(replacements)))))
  for (path in list.files(docs, "\\.html$", recursive=TRUE, full.names=TRUE)) {
    text <- paste(readLines(path, warn=FALSE, encoding="UTF-8"), collapse="\n")
    positions <- gregexpr('<link\\b[^>]*>', text, perl=TRUE)
    tags <- regmatches(text, positions)[[1]]
    updated <- tags
    for (old in names(replacements)) {
      hit <- grepl(old, updated, fixed=TRUE)
      updated[hit] <- gsub(old, replacements[[old]], updated[hit], fixed=TRUE)
      size <- if (startsWith(old,"favicon")) "96x96" else "180x180"
      updated[hit] <- gsub('sizes="[0-9]+x[0-9]+"',
        paste0('sizes="',size,'"'), updated[hit])
    }
    if (!identical(tags, updated)) {
      updated[duplicated(updated)] <- ""
      regmatches(text, positions) <- list(updated)
      writeLines(text, path, useBytes=TRUE)
    }
  }
  invisible(docs)
}
