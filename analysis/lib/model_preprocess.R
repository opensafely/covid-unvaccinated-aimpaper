# function for preprocessing data for glm

model_preprocess <- function(g) {
  
  cat(glue("#### read data ####\n"))
  data <- read_rds(here::here("output", "data", glue("data_processed_{g}.rds"))) %>%
    droplevels() %>%
    # remove continuous age and region
    select(-age, -region) 
  
  cat(glue("#### check factors ####\n"))
  # check all variables are factors and stop if not
  check_factors <- sapply(data %>% select(-weight, -vax_12), is.factor)
  if (!all(check_factors)) stop(glue("Stopped preprocessing for group {g} due to non factor variable(s): ",
                                     str_c(names(data %>% select(-weight, -vax_12))[!check_factors], collapse = ", ")))
  
  cat(glue("#### check levels ####\n"))
  # check for any factors with one level and remove
  lev1 <- sapply(data %>% select(-weight, -vax_12), function(x) length(levels(x))==1)
  if (any(lev1)) {
    print(str_c(glue("Variables with one level for group {g} removed: ",
                     str_c(names(data %>% select(-weight, -vax_12))[lev1], collapse = ", "))))
    data <- data %>%
      select(-all_of(names(data %>% select(-weight, -vax_12))[lev1]))
  }
  
  cat(glue("#### check n ####\n"))
  # check for levels with n < 10 and remove
  less10 <- data %>% 
    select(-weight) %>%
    pivot_longer(cols = -vax_12) %>%
    group_by(vax_12,name,value) %>%
    count() %>%
    ungroup() %>% 
    filter(n<10) %>%
    distinct(name) %>%
    unlist() %>%
    unname()
  if (length(less10) > 0) {
    print(str_c(glue("Variables with n<10 for any outcome:category combination removed: ", str_c(less10, collapse = ", "))))
    data <- data %>%
      select(-all_of(less10))
  }
  
  return(data)
  
}