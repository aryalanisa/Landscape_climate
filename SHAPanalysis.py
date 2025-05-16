import pandas as pd
import xgboost as xgb
import shap
import matplotlib.pyplot as plt

# Define your files
lst_model_files = .... #path to your models
lst_data_files = ....   #path yo your files

lstvar_model_files = .... #path to your second target models
lstvar_data_files = ....   #path to your second target files

#create categories
categories = {
    'Topography': ['Elevation', 'Slope', 'Aspect'],  
    'Land Cover': ['Forest', 'Grassland', 'Cropland', 'Builtups', 'Bareland', 'water', 'herb_wetland'],
    'Diversity metrics': ['Shannondiversity', 'Simpsondiversity', 'entropy', 'Patchrichness', 'Patchdensity', 'Numberofpatch'],
    'Area and Edge metrics':['Meanpatcharea', 'edgedensity'],
    'Shape metrics' :['Shapeindex'],
    'Core area metrics' :['Coreareaindex'],
    'Aggregation metrics' :['Aggregationindex', 'IJI', 'cohesion', 'contagion'],
    'Complexity metrics' :['division',  'Meshsize', 'Split']
}
#Gridsize
grid_sizes = ['1', '25', '100', '225', '400']

colors = {
    'Topography': 'blue',
    'Diversity metrics': 'red',
    'Land Cover': 'green',
    'Area and Edge metrics': 'orange',
    'Shape metrics': 'teal',
    'Core area metrics': 'brown',
    'Aggregation metrics': 'indigo',
    'Complexity metrics': 'magenta'
    
}

markers = {
   'Topography': 'x',
    'Diversity metrics': 'o',
    'Land Cover': 's',
    'Area and Edge metrics': '+',
    'Shape metrics': '*',
    'Core area metrics': 'v',
    'Aggregation metrics': 'd',
    'Complexity metrics': '^'
}
#categorical SHAP sum using individual absoulte SHAP values
def compute_category_shap_values(models, datasets):
    shap_values_by_category = {k: [] for k in categories.keys()}
    for model, data in zip(models, datasets):
        booster = xgb.Booster()
        booster.load_model(model)
        data_df = pd.read_csv(data)
        explainer = shap.TreeExplainer(booster)
        shap_values = explainer.shap_values(data_df)
        for category, features in categories.items():
            shap_sum = sum(abs(shap_values[:, data_df.columns.get_loc(f)]) for f in features if f in data_df.columns)
            shap_values_by_category[category].append(shap_sum / len(data_df))
    return shap_values_by_category
# Load models and data
lst_models = [xgb.Booster() for _ in lst_model_files]
for m, f in zip(lst_models, lst_model_files):
    m.load_model(f)
lst_datasets = [pd.read_csv(f) for f in lst_data_files]

lstvar_models = [xgb.Booster() for _ in lstvar_model_files]
for m, f in zip(lstvar_models, lstvar_model_files):
    m.load_model(f)
lstvar_datasets = [pd.read_csv(f) for f in lstvar_data_files]
# Use SHAP to calculate values for each group
def extract_shap_by_category(models, datasets):
    results = {cat: [] for cat in categories}
    for model, data in zip(models, datasets):
        explainer = shap.TreeExplainer(model)
        shap_values = explainer.shap_values(data)
        for cat, feats in categories.items():
            val = 0
            for f in feats:
                if f in data.columns:
                    val += abs(shap_values[:, data.columns.get_loc(f)]).mean()
            results[cat].append(val)
    return results

lst_shap = extract_shap_by_category(lst_models, lst_datasets)
lstvar_shap = extract_shap_by_category(lstvar_models, lstvar_datasets)

fig, axes = plt.subplots(1, 2, figsize=(14, 6), sharey=True)
# Define y-ticks and labels
y_ticks = [0.05, 0.1, 0.2, 0.5, 1.0, 1.5, 2]
y_labels = ['0.05', '0.1', '0.2', '0.5', '1', '1.5', '2']

            # Plot 1: Max Temperature (LST)
for cat in categories:
    axes[0].plot(
        grid_sizes, lst_shap[cat],
        linestyle='-', marker=markers[cat], color=colors[cat], label=cat
    )
axes[0].set_title("AMT")
axes[0].set_xlabel("Grid size (km²)")
axes[0].set_ylabel("Log₁₀(SHAP Values)")
axes[0].set_yscale('log')
axes[0].set_yticks(y_ticks)
axes[0].set_yticklabels(y_labels)
axes[0].grid(True, which='both', linestyle='--', linewidth=0.5)

# Plot 2: Temperature Variability (LSTvar)
for cat in categories:
    axes[1].plot(
        grid_sizes, lstvar_shap[cat],
        linestyle='-', marker=markers[cat], color=colors[cat], label=cat
    )
axes[1].set_title("AMT-var")
axes[1].set_xlabel("Grid size (km²)")
axes[1].set_yscale('log')
axes[1].set_yticks(y_ticks)
axes[1].set_yticklabels(y_labels)
axes[1].grid(True, which='both', linestyle='--', linewidth=0.5)
# Rotate ticks and layout
for ax in axes:
    ax.tick_params(axis='x', rotation=45)

# Legend outside the plot
fig.legend(
    handles=axes[0].get_legend_handles_labels()[0],
    labels=axes[0].get_legend_handles_labels()[1],
    loc='center left',
    bbox_to_anchor=(0.85, 0.3),
    frameon=True,
    title='Categories'
)
# Add subplot labels (a) and (b)
axes[0].text(-0.1, 1, '(a)', transform=axes[0].transAxes, fontsize=12, fontweight='bold')
axes[1].text(-0.1, 1, '(b)', transform=axes[1].transAxes, fontsize=12, fontweight='bold')

plt.tight_layout(rect=[0, 0, 0.85, 1])  # Leave space on right for legend
plt.show()
