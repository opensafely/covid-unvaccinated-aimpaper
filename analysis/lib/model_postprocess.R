# process model output

model_postprocess <- function(.data) {
  
  
  # process output from fully adjusted model (returned from model_fadj)
  if (class(.data) == "summary.glm") {
    
    covs <- names(.data$levels)
    
    res <- as_tibble(.data$confint, rownames = "category") %>%
      left_join(
        as_tibble(.data$coefficients, rownames = "category"),
        by = "category"
      ) %>%
      select(1:4) %>%
      filter(!(category %in% "(Intercept)"))
    names(res) <- c("category", "lower", "upper", "estimate")
    
    var_names <- unlist(.data$levels)
    res <- tibble(variable = str_remove(names(var_names),"\\d+$"),
                  category = var_names) %>%
      mutate(key = str_c(variable, category)) %>%
      left_join(res,
                by = c("key" = "category")) %>%
      select(-key)
    
    for (v in covs) {
      
      # if variable has levels 0,1, remove category
      # otherwise join to all factor levels
      levs <- .data$levels[[v]]
      if (all(levs %in% c("0", "1"))) {
        res <- res %>%
          filter(!((variable %in% v) & category %in% "0")) %>%
          mutate(across(category,
                        ~if_else(
                          variable %in% v,
                          "", .)))
      } 
    }
    
    out <- res
    
    
    # process output from unadjusted and partially adjusted models (model_unadj or model_padj)
  } else {
    
    covs <- names(.data)
    out <- tibble()
    
    for (v in covs) {
      
      if (class(.data[[v]]) != "summary.glm") stop("Input must have class summary.glm")
      
      # extract estimates and confidence intervals
      res <- as_tibble(.data[[v]]$confint, rownames = "category") %>%
        left_join(
          as_tibble(.data[[v]]$coefficients, rownames = "category"),
          by = "category"
        ) %>%
        select(1:4)
      names(res) <- c("category", "lower", "upper", "estimate")
      
      # results tibble
      res <- res %>%
        mutate(variable = v,
               category = str_remove(category, v))
      
      # if variable has levels 0,1, remove category
      # otherwise join to all factor levels
      levs <- .data[[v]]$levels
      if (all(levs %in% c("0", "1"))) {
        res <- res %>%
          mutate(category = "")
      } else {
        # construct tibble
        res <-  tibble(category = levs) %>%
          mutate(variable = v) %>%
          left_join(res, by = c("category", "variable"))
      }
      
      # bind to existing results
      out <- bind_rows(out, res)
    }
  }
  
  out <- out %>%
    group_by(variable) %>%
    # check for variables with all NA estimates
    mutate(failed = all(is.na(estimate))) %>%
    ungroup() %>%
    
    mutate(across(c(estimate, lower, upper),
                  ~format(round(exp(.),2),nsmall=2))) %>%
    mutate(OR = str_c(estimate, " (", lower, "-", upper, ")")) %>%
    # calculate odds ratio by taking exp(estimate)
    mutate(across(OR,
                  ~case_when(
                    str_detect(., "NA") & failed ~ "glm failed",
                    str_detect(., "NA") & !failed ~ "1    (ref)",
                    TRUE ~ .))) %>%
    # clean variable names
    sanitise_variables(variable) %>%
    transmute(characteristic = if_else(
      category == "",
      variable,
      str_c(variable, category, sep = ": ")),
      OR)
  
  return(out)
  
}