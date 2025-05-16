library(raster)
library(sf)
library(sp)
library(dplyr)
library(landscapemetrics)
library(ggplot2)

land_use_map <- raster("PHD/Data/land_utm.tif")
slope_raster <- raster("PHD/data/slope.tif")
aspect_raster <- raster("PHD/data/aspect.tif")
elevation_raster <- raster("PHD/data/elevation.tif")

# Define the resolution of the grid (1 km²)
grid_resolution <- 1000  # 1 km in meters

# Create a grid over the raster extent
grid <- st_make_grid(st_as_sfc(st_bbox(land_use_map)), cellsize = c(grid_resolution, grid_resolution))

# Convert the grid to an sf object
grid_sf <- st_sf(grid_id = 1:length(grid), geometry = grid)

# Sample 1% of the grid cells
set.seed(123)
sampled_grid <- grid_sf %>% sample_frac(0.01)

# Define the list of metrics you want to calculate
metrics_list <- c("lsm_l_area_mn",    # Mean Patch Area
                  "lsm_l_cai_mn",     # Mean Core Area Index
                  "lsm_l_cohesion",   # Patch Cohesion Index
                  "lsm_l_contag",     # Contagion Index
                  "lsm_l_ent",        # Entropy
                  "lsm_l_ai",         # Aggregation Index
                  "lsm_l_ed",         # Edge Density
                  "lsm_l_np",         # Number of Patches
                  "lsm_l_pd",         # Patch Density
                  "lsm_l_pr",         # Patch Richness
                  "lsm_l_shape_mn",   # Mean Shape Index
                  "lsm_l_sidi",       # Simpson's Diversity Index
                  "lsm_l_siei",       # Simpson's Evenness Index
                  "lsm_l_iji",        # Interspersion and Juxtaposition Index (IJI)
                  "lsm_l_shdi",       # Shannon's Diversity Index
                  "lsm_l_shei",       # Shannon's Evenness Index
                  "lsm_l_split",      # Splitting Index
                  "lsm_l_division",   # Division Index
                  "lsm_l_mesh",      # Effective Mesh Size
                  "lsm_c_pland")     #classpercent


# Initialize a list to store the results
results_list <- list()

# Loop through each sampled grid cell
for (i in seq_len(nrow(grid_sf))) {
  # Get the polygon for the current grid cell
  grid_cell <- st_geometry(grid_sf[i,])
  
  # Crop the land use map to the current grid cell's extent
  cropped_raster <- crop(land_use_map, st_bbox(grid_cell))
  
  # Mask the cropped raster using the grid cell polygon
  masked_raster <- mask(cropped_raster, as(grid_cell, "Spatial"))
  
  # Ensure the masked raster is not empty
  if (!is.null(masked_raster) && ncell(masked_raster) > 0) {
    # Calculate landscape metrics for the current grid cell raster
    metrics <- calculate_lsm(masked_raster, level = "landscape", what = metrics_list)
    
    # Only proceed if metrics were successfully calculated
    if (!is.null(metrics)) {
      # Crop and mask the other rasters and calculate mean values
      cropped_slope <- mask(crop(slope_raster, st_bbox(grid_cell)), as(grid_cell, "Spatial"))
      cropped_aspect <- mask(crop(aspect_raster, st_bbox(grid_cell)), as(grid_cell, "Spatial"))
      cropped_elevation <- mask(crop(elevation_raster, st_bbox(grid_cell)), as(grid_cell, "Spatial"))
      
      
      mean_slope <- cellStats(cropped_slope, stat = "mean", na.rm = TRUE)
      mean_aspect <- cellStats(cropped_aspect, stat = "mean", na.rm = TRUE)
      mean_elevation <- cellStats(cropped_elevation, stat = "mean", na.rm = TRUE)
      
      
      # Add the grid ID and calculated values to the metrics
      metrics$grid_id <- grid_sf$grid_id[i]
      metrics$mean_slope <- mean_slope
      metrics$mean_aspect <- mean_aspect
      metrics$mean_elevation <- mean_elevation
    

    # Store the results
      results_list[[i]] <- metrics
    }
  } else {
    message(paste("Empty or invalid raster for grid cell:", i))
  }
  
  # Optionally print progress
  if (i %% 10 == 0) {
    message(paste("Processed", i, "of", nrow(grid_sf), "grid cells"))
  }
    }

    # Combine all results into a single data frame
    all_metrics_with_topo <- do.call(rbind, results_list)

    # Save the combined data to a CSV file
    write.csv(all_metrics_with_topo, "landscape_metrics.csv")

    # View the final data
    print(all_metrics_with_topo)
    


# Specify the destination folder
destination_folder <- "PHD"  # Replace with your folder path

# Ensure the folder exists (create it if it doesn't)
if (!dir.exists(destination_folder)) {
  dir.create(destination_folder, recursive = TRUE)
}

# Specify the full path for the output CSV file
output_file <- file.path(destination_folder, "Metrics_new.csv")

 # Save the combined data to a CSV file
write.csv(all_metrics_with_topo, output_file, row.names = FALSE)

# Confirm that the file has been saved
message(paste("Metrics saved to:", output_file))

# Combine all results into a single data frame
all_metrics <- do.call(rbind, results_list)

# Save the metrics to a CSV file
write.csv(all_metrics, "landscape_metrics_sampled.csv")

# View the metrics
print(all_metrics)

# Specify the destination folder
destination_folder <- "PHD"  # Replace with your folder path

# Ensure the folder exists (create it if it doesn't)
if (!dir.exists(destination_folder)) {
  dir.create(destination_folder, recursive = TRUE)
}

# Specify the full path for the output CSV file
output_file <- file.path(destination_folder, "landscape_metrics_sampled.csv")

# Save the metrics to the specified CSV file
write.csv(all_metrics, output_file, row.names = FALSE)

# Confirm that the file has been saved
message(paste("Metrics saved to:", output_file))

# Load necessary libraries
library(tidyr)
library(dplyr)

# Assuming your data is in a data frame called df
df <- read.csv("PHD/Metrics_new.csv")

# Pivot the data so that 'metric' becomes the column headers
df_pivoted <- df %>%
  spread(key = metric, value = value)

# Specify the full path for the output CSV file
output_file <- file.path(destination_folder, "Metrics_class.csv")

# Save the metrics to the specified CSV file
write.csv(df_pivoted, output_file, row.names = FALSE)

# Confirm that the file has been saved
message(paste("Metrics saved to:", output_file))


