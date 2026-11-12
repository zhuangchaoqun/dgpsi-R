# Give each component an imputation stream independent of the network's layer
# order. The native constructor samples each component; the native predictor
# still handles all retained links. No predictions or variances are replaced.
.prunlgp_activate <- function(object, B, seed) {
  layers <- object$constructor_obj
  metadata <- object$specs$metadata
  ids <- sort(as.character(metadata$Emulator))
  states <- lapply(layers, function(layer) vector("list", length(layer)))
  for (i in seq_len(nrow(metadata))) {
    row <- metadata[i, ]
    l <- as.integer(row$Layer); k <- as.integer(row$Pos_in_Layer)
    component_seed <- as.integer((as.double(seed) +
      130363 * match(as.character(row$Emulator), ids)) %% 2147483646 + 1)
    set_seed(component_seed)
    one <- pkg.env$dgpsi$lgp(all_layer = list(list(layers[[l]][[k]])),
                            N = as.integer(B))
    states[[l]][[k]] <- lapply(one$all_layer_set, function(z) z[[1]][[1]])
  }
  # A GP has a single deterministic state, repeated alongside DGP imputations.
  count <- max(unlist(lapply(states, lengths)))
  imputations <- lapply(seq_len(count), function(b)
    lapply(states, function(layer) lapply(layer, function(z)
      z[[if (length(z) == 1L) 1L else b]])))
  engine <- pkg.env$dgpsi$lgp(all_layer = layers, N = 0L)
  engine$all_layer_set <- imputations
  object$emulator_obj <- engine
  object$specs$seed <- as.integer(seed)
  object$specs$B <- as.integer(B)
  object$specs$prunlgp_component_streams <- TRUE
  object
}
