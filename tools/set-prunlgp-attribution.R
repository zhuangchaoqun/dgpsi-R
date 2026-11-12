# Credit only the prunlgp function and its two tutorials.
# All other pages retain the upstream package author credits.
set_prunlgp_attribution <- function(root) {
  pages <- c("reference/prunlgp.html", "articles/prunlgp.html",
             "articles/prunlgp-operational.html")
  for (page in pages) {
    path <- file.path(root, "docs", page)
    if (!file.exists(path)) stop("Missing rendered page: ", page)
    html <- paste(readLines(path, warn=FALSE, encoding="UTF-8"), collapse="\n")
    footer <- '(?s)<div class="pkgdown-footer-left">.*?</div>'
    matches <- gregexpr(footer, html, perl=TRUE)[[1]]
    if (length(matches) != 1L || matches[1] < 0L) {
      stop("Expected one pkgdown author footer in ", page)
    }
    credit <- "Developed by Chaoqun Zhuang."
    html <- sub(footer, paste0('<div class="pkgdown-footer-left">\n  <p>',
                              credit, '</p>\n</div>'), html, perl=TRUE)
    # Also support refreshing already executed articles without refitting models.
    # Newly rendered articles obtain this byline from their YAML author field.
    if (startsWith(page, "articles/")) {
      header <- regmatches(html, regexpr(
        '(?s)<div class="page-header">.*?</div>', html, perl=TRUE))
      if (!length(header)) stop("Missing article header in ", page)
      if (!grepl("Chaoqun Zhuang", header, fixed=TRUE)) {
        updated <- sub("</h1>",
          '</h1>\n      <p class="author">Chaoqun Zhuang</p>', header, fixed=TRUE)
        html <- sub(header, updated, html, fixed=TRUE)
      }
    }
    writeLines(html, path, useBytes=TRUE)
  }
  invisible(pages)
}
