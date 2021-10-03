# unadjusted model

model_unadj <- function(.data, v) {
  
  if (v == "preg_elig_group") {
    data_mod <- .data %>%
      filter(sex %in% "F")
  } else {
    data_mod <- .data
  }
  
  cat(glue("#### apply model ####\n"))
  mod <- glm(formula = as.formula(glue("vax_12 ~ {v}")), 
             family = "binomial", 
             weights = weight,
             data = data_mod)
  
  # don't need full model so save summary to save space
  out <- summary(mod)
  
  # levels to calculate confidence intervals for
  parms <- str_c(v, levels(data_mod[,v][[1]]))[-1]
  
  cat(glue("#### calculate confidence intervals ####\n"))
  # add confidence intervals to output
  out$confint <- confint(mod, parm = parms) 
  
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
