# partially adjusted model

model_padj <- function(.data, v, adjust = c("ageband", "sex", "stp")) {
  
  # remove ageband if only one level in data (e.g. for group 05)
  adjust <- adjust[adjust %in% names(.data)]
  # make sure covariate v not appearing twice
  adjust <- unique(c(v, adjust))
  
  mod <- glm(formula = as.formula(str_c("vax_12 ~ ", str_c(adjust, collapse = "+"))), 
             family = "binomial", 
             weights = weight,
             data = .data)
  
  # don't need full model so save summary to save space
  out <- summary(mod)
  
  # levels to calculate confidence intervals for
  parms <- str_c(v, levels(.data[,v][[1]]))[-1]
  
  # add confidence intervals to output
  out$confint <- confint(mod, parm = parms)
  
  if (length(adjust) >=2) {
    # add VIF to output
    out$vif <- car::vif(mod)
  } else {
    out$vif <- NULL
  }
  
  
  # if length(parms)==1 then change to matrix and add names, as R converted to vector
  if (length(parms) == 1) {
    confint_names <- names(out$confint)
    out$confint <- matrix(out$confint, nrow=1)
    dimnames(out$confint) <- list(parms,confint_names)
  }
  
  # add all factor levels to output
  out$levels <- levels(.data[,v][[1]])
  
  return(out)
  
}