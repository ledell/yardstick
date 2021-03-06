#' Precision
#'
#' These functions calculate the [precision()] of a measurement system for
#' finding relevant documents compared to reference results
#' (the truth regarding relevance). Highly related functions are [recall()]
#' and [f_meas()].
#'
#' The precision is the percentage of predicted truly relevant results
#' of the total number of predicted relevant results and
#' characterizes the "purity in retrieval performance" (Buckland
#' and Gey, 1994).
#'
#' When the denominator of the calculation is `0`, precision is undefined. This
#' happens when both `# true_positive = 0` and `# false_positive = 0` are true,
#' which mean that there were no predicted events. When computing binary
#' precision, a `NA` value will be returned with a warning. When computing
#' multiclass precision, the individual `NA` values will be removed, and the
#' computation will procede, with a warning.
#'
#' @family class metrics
#' @family relevance metrics
#' @templateVar metric_fn precision
#' @template event_first
#' @template multiclass
#' @template return
#' @template table-relevance
#'
#' @inheritParams sens
#'
#' @references
#'
#' Buckland, M., & Gey, F. (1994). The relationship
#'  between Recall and Precision. *Journal of the American Society
#'  for Information Science*, 45(1), 12-19.
#'
#' Powers, D. (2007). Evaluation: From Precision, Recall and F
#'  Factor to ROC, Informedness, Markedness and Correlation.
#'  Technical Report SIE-07-001, Flinders University
#'
#' @author Max Kuhn
#'
#' @template examples-class
#'
#' @export
precision <- function(data, ...) {
  UseMethod("precision")
}

class(precision) <- c("class_metric", "function")
attr(precision, "direction") <- "maximize"

#' @rdname precision
#' @export
precision.data.frame <- function(data, truth, estimate,
                                 estimator = NULL,
                                 na_rm = TRUE, ...) {

  metric_summarizer(
    metric_nm = "precision",
    metric_fn = precision_vec,
    data = data,
    truth = !!enquo(truth),
    estimate = !!enquo(estimate),
    estimator = estimator,
    na_rm = na_rm,
    ... = ...
  )

}

#' @export
precision.table <- function (data, estimator = NULL, ...) {

  check_table(data)
  estimator <- finalize_estimator(data, estimator)

  metric_tibbler(
    .metric = "precision",
    .estimator = estimator,
    .estimate = precision_table_impl(data, estimator)
  )

}

#' @export
precision.matrix <- function(data, estimator = NULL, ...) {

  data <- as.table(data)
  precision.table(data, estimator)

}

#' @export
#' @rdname precision
precision_vec <- function(truth, estimate,
                          estimator = NULL, na_rm = TRUE, ...) {

  estimator <- finalize_estimator(truth, estimator)

  precision_impl <- function(truth, estimate) {

    xtab <- vec2table(
      truth = truth,
      estimate = estimate
    )

    precision_table_impl(xtab, estimator)
  }

  metric_vec_template(
    metric_impl = precision_impl,
    truth = truth,
    estimate = estimate,
    na_rm = na_rm,
    estimator = estimator,
    cls = "factor",
    ...
  )

}

precision_table_impl <- function(data, estimator) {

  if(is_binary(estimator)) {
    precision_binary(data)
  } else {
    w <- get_weights(data, estimator)
    out_vec <- precision_multiclass(data, estimator)
    # set `na.rm = TRUE` to remove undefined values from weighted computation (#98)
    weighted.mean(out_vec, w, na.rm = TRUE)
  }

}

precision_binary <- function(data) {

  relevant <- pos_val(data)
  numer <- data[relevant, relevant]
  denom <- sum(data[relevant, ])

  undefined <- denom <= 0
  if (undefined) {
    not_relevant <- setdiff(colnames(data), relevant)
    count <- data[not_relevant, relevant]
    warn_precision_undefined_binary(relevant, count)
    return(NA_real_)
  }

  numer / denom

}

precision_multiclass <- function(data, estimator) {

  numer <- diag(data)
  denom <- rowSums(data)

  undefined <- denom <= 0
  if (any(undefined)) {
    counts <- colSums(data) - numer
    counts <- counts[undefined]
    events <- colnames(data)[undefined]
    warn_precision_undefined_multiclass(events, counts)
    numer[undefined] <- NA_real_
    denom[undefined] <- NA_real_
  }

  # set `na.rm = TRUE` to remove undefined values from weighted computation (#98)
  if(is_micro(estimator)) {
    numer <- sum(numer, na.rm = TRUE)
    denom <- sum(denom, na.rm = TRUE)
  }

  numer / denom

}

warn_precision_undefined_binary <- function(event, count) {
  message <- paste0(
    "While computing binary `precision()`, no predicted events were detected ",
    "(i.e. `true_positive + false_positive = 0`). ",
    "\n",
    "Precision is undefined in this case, and `NA` will be returned.",
    "\n",
    "Note that ", count, " true event(s) actually occured for the problematic ",
    "event level, '", event, "'."
  )

  warn_precision_undefined(
    message = message,
    events = event,
    counts = count,
    .subclass = "yardstick_warning_precision_undefined_binary"
  )
}

warn_precision_undefined_multiclass <- function(events, counts) {
  message <- paste0(
    "While computing multiclass `precision()`, some levels had no predicted events ",
    "(i.e. `true_positive + false_positive = 0`). ",
    "\n",
    "Precision is undefined in this case, and those levels will be removed from the averaged result.",
    "\n",
    "Note that the following number of true events actually occured for each problematic event level:",
    "\n",
    paste0("'", events, "': ", counts, collapse = "\n")
  )

  warn_precision_undefined(
    message = message,
    events = events,
    counts = counts,
    .subclass = "yardstick_warning_precision_undefined_multiclass"
  )
}

warn_precision_undefined <- function(message, events, counts, ..., .subclass = character()) {
  rlang::warn(
    message = message,
    .subclass = c(.subclass, "yardstick_warning_precision_undefined"),
    events = events,
    counts = counts,
    ...
  )
}
