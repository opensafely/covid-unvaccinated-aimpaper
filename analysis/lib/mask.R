mask <- function(.data, var, min_value = 5) {
  library(tidyverse)
  .data %>%
    mutate(across({{var}}, ~if_else(. < 5, 5L, as.integer(.))))
    
}