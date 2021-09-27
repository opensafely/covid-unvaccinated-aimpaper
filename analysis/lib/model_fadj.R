# partially adjusted model

model_fadj <- function(.data) {
  
  mod <- glm(formula = vax_12 ~ .-weight, 
             family = "binomial", 
             weights = weight,
             data = .data)
  
  # don't need full model so save summary to save space
  out <- summary(mod)
  
  # add confidence intervals to output
  out$confint <- confint(mod)
  
  # add VIF to output
  if (ncol(.data %>% select(-vax_12, -weight)) >=2) {
    # add VIF to output
    out$vif <- car::vif(mod)
  } else {
    out$vif <- NULL
  }
  
  # add all factor levels to output
  out$levels <- lapply(.data %>% select(-vax_12), levels)
  
  return(out)
  
}