//Import entries
var roi = ee.FeatureCollection("users/your_username/your_roi");
var imageCollection2 = ee.ImageCollection("MODIS/006/MOD11A2");
var band = ['LST_Day_1km'];

//date of interest
var startdate = '2023-04-01'
var enddate = '2023-10-31'

//Filtering the image collection 
var MODIS = imageCollection2
  .filterBounds(roi)
  .filterDate(startdate, enddate).select(band);
 
 // Function to convert Kelvin to Celsius
function kelvinToCelsius(image) {
  var celsius = image.select(['LST_Day_1km']).multiply(0.02).subtract(273.15).rename('LST_Celsius');
  return image.addBands(celsius).copyProperties(image, ['system:time_start']);
}
 //Finding maximum LST over time
var maxLST = MODIS.map(kelvinToCelsius).max();

//CLip and select the result
var lusatia = maxLST.clip(roi)
var lst = lusatia.select('LST_Celsius')

//Add layer 
Map.addLayer(lst, {
  min: 0,  // Adjust the visualization parameters as needed
  max: 40,
  palette: ['040274', '040281', '0502a3', '0502b8', '0502ce', '0502e6', '0602ff', '235cb1', '307ef3', '269db1', '30c8e2', '32d3ef', '3be285', '3ff38f', '86f08a', '3ae237', 'b5e22e', 'd6e21f', 'fff705', 'ffd611', 'ffb613', 'ff8b13', 'ff6e08', 'ff500d', 'ff0000', 'de0101', 'c21301', 'a71001', '911003']
}, 'Maximum LST');

//Export your image in required format
Export.image.toDrive({
  image: lst,
  description: 'lst2019',
  scale: 1000,
  region: roi,
  folder: 'MODIS',
  fileFormat: 'Geotiff',
  formatOptions: {
    cloudOptimized: true
  }
});
