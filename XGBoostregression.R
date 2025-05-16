library(readxl)
library(dplyr)
library(tidyr)
library(caret)
library(rBayesianOptimization)
library(xgboost)

data <- read_excel("PHD/Original/Data1.xlsx")
columns_statistical <- c("Aspect", "Elevation", "Slope")  # Columns to use statistical imputation
columns_zero <- setdiff(colnames(data), c("LST", "LSTvar", columns_statistical))
print(data)
# Convert all factors to numeric 
data <- data %>%
  mutate(across(everything(), ~ as.numeric(.)))

# Replace NAs with 0 for specified columns
data <- data %>%
  mutate(across(everything(), ~ replace_na(., 0)))

# Replace NAs with mean for specified columns
data <- data %>%
  mutate(across(all_of(columns_statistical), ~ replace_na(., mean(., na.rm = TRUE))))

# Convert all factors to numeric 
data <- data %>%
  mutate(across(everything(), ~ as.numeric(.)))


# Define predictor columns (excluding target columns)
features <- setdiff(colnames(data), c("LST", "LSTvar", "grid_id"))
target <- "LST" 

# Convert the data to matrix format for XGBoost
X <- as.matrix(data[features])
y <- data[[target]]

set.seed(123) # Set seed for reproducibility
trainIndex <- createDataPartition(y, p = 0.8, list = FALSE)
X_train <- X[trainIndex,]
y_train <- y[trainIndex]
X_test <- X[-trainIndex,]
y_test <- y[-trainIndex]

# Convert data frames to numeric matrices
X_train <- as.matrix(X_train)
X_test <- as.matrix(X_test)

objective_function <- function(nrounds, max_depth, eta, min_child_weight, subsample, colsample_bytree) {
  
  # Convert to integer where needed
  max_depth <- as.integer(max_depth)
  min_child_weight <- as.integer(min_child_weight)
  
  # Create DMatrix
  dtrain <- xgb.DMatrix(data = X_train, label = y_train)
  dtest <- xgb.DMatrix(data = X_test, label = y_test)
  
  # Train the model
  model <- xgboost(
    data = dtrain,
    nrounds = as.integer(nrounds),
    max_depth = max_depth,
    eta = eta,
    min_child_weight = min_child_weight,
    subsample = subsample,
    colsample_bytree = colsample_bytree,
    objective = "reg:squarederror",
    verbose = 0
  )
  
  # Make predictions
  predictions <- predict(model, newdata = X_test)
  
  # Calculate RMSE
  rmse <- sqrt(mean((y_test - predictions)^2))
  
  # Return the RMSE to minimize
  return(list(Score = -rmse))
}

param_bounds <- list(
  nrounds = c(50, 250),
  max_depth = c(3, 10),
  eta = c(0.01, 0.3),
  min_child_weight = c(1, 10),
  subsample = c(0.6, 1),
  colsample_bytree = c(0.6, 1)
)

opt_result <- BayesianOptimization(
  FUN = objective_function,
  bounds = param_bounds,
  init_points = 10,       # Number of initial random points
  n_iter = 20,            # Number of iterations for Bayesian optimization
  acq = "ei",             # Acquisition function (Expected Improvement)
  kappa = 2.576,          # kappa for acquisition function
  verbose = TRUE          # Print progress
)

# Print the best hyperparameters found
print(opt$Best_Par)

# Define the best parameters from the optimization
best_params <- list(
  nrounds = round(opt_result$Best_Par["nrounds"]),
  max_depth = round(opt_result$Best_Par["max_depth"]),
  eta = opt_result$Best_Par["eta"],
  min_child_weight = opt_result$Best_Par["min_child_weight"],
  subsample = opt_result$Best_Par["subsample"],
  colsample_bytree = opt_result$Best_Par["colsample_bytree"]
)

# Retrain the model with best parameters
final_model <- xgboost(
  data = X_train,
  label = y_train,
  nrounds = best_params$nrounds,
  max_depth = best_params$max_depth,
  eta = best_params$eta,
  min_child_weight = best_params$min_child_weight,
  subsample = best_params$subsample,
  colsample_bytree = best_params$colsample_bytree,
  objective = "reg:squarederror",
  verbose = 1
)

# Save the model to a file
xgb.save(final_model, "newlstvar1.model")

# Make predictions on the test set
predictions <- predict(final_model, newdata = X_test)

# Calculate RMSE
rmse <- sqrt(mean((y_test - predictions)^2))
print(paste("Final RMSE on test set: ", rmse))

# Calculate Mean Absolute Error (MAE)
mae <- mean(abs(y_test - predictions))
print(paste("Final MAE on test set: ", mae))

# Actual values
actuals <- y_test
# Predictions from the model
predictions <- predict(final_model, newdata = X_test)

# Compute the residuals
residuals <- actuals - predictions

# Total sum of squares (SST)
sst <- sum((actuals - mean(actuals))^2)

# Residual sum of squares (SSE)
sse <- sum(residuals^2)

# R-squared
r2 <- 1 - (sse / sst)