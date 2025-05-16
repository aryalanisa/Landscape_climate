# Maximum LST 
This script uses Google Earth Engine to compute the maximum daytime land surface temperature (LST) in Celsius from MODIS data (`MOD11A1`) for a region of interest (ROI) between your time of interest (e.g. April 2023-October 2023).

## Key Steps
- Filter MODIS images by date and region
- Convert LST from Kelvin to Celsius
- Compute pixel-wise maximum
- Clip to ROI

## Output
A single image of maximum LST per pixel in °C
