
# Situate

Situate is a system for active grounding of situations in images. 


# Running Situate

### Experiment parameters file
	
The *experiment parameters* file specifies:
- the situation definition
- the Situate running parameters
- the training and testing images
- visualization settings
	
example: "parameters_experiment_dogwalking_viz.json"
	
#### Situation definition file
	
The *situation definition* file specifies 
- the situation objects that make up the situation
- a mapping from possible labels (found in training data) to the situation objects

example: "situation_definitions/dogwalking.json"

#### Situate running parameters file
	
The *Situate running parameters* file defines the functions that are used by situate. These includes the functions used to train and apply the classifier, to define and apply the conditional relationships among objects, and numerous others.

example: "parameters_situate_default.json"

A list of several *Situate running parameters* files can be included in the *experiment parameters file*. If this is the case, each parameterization will be run.

#### Training and testing image directories

	"directory_train" : "/Users/Max/Documents/images/DogWalking_PortlandSimple_train/",
	"directory_test"  : "/Users/Max/Documents/images/DogWalking_PortlandSimple_test/",

#### Additional settings

	"use_parallel"                  : 0, 
	"run_analysis_after_completion" : 0,
	"num_folds"                     : 1,
	"use_visualizer"                : 0,
	"specific_folds"                : [1],
	"max_testing_images"            : "",
	"testing_seed"                  : ""
			
### Run
	
To run Situate, call with an experiment parameters file

	situate.experiment_run( 'parameters_experiment_dogwalking_viz.json' );





# Defining a Situation

Defining a new situation requires a file that defines the situation and positive training images that have labels specifying the relevant objects in the image. 

### Situation definition file

Situation definition files are in JSON format. They include a simple description of the situation and a list of constituent objects. The constituent objects have a list of labels that may be present in the training data.

	{ 
		"situation":{

			"description" : "urn",
			
			"situation_objects" : {

				"black_ball" : {
					"possible_labels" : [
						"black_ball_big",
						"black_ball_small"],
					"urgency_pre"  : "1.0",
					"urgency_post" : ".25"
				},

				"white_ball" : {
					"possible_labels" : [
						"white_ball_big",
						"white_ball_small"],
					"urgency_pre"  : "1.0",
					"urgency_post" : ".25"
				}
			}
		}
	}

Situation definition files are stored in *situation_definitions/*

### Labeled data

Labels on training images define tight bounding boxes for situation objects in the image.
Labels can be generated with the tool:
	
	labels_generate('my_image_directory/');

These images and label files will be used to learn the relationships between objects (via the situation model), and classifiers for each of the constituent objects. The reliability of the individual classifiers is often used to weight the classifier output when using it to evaluate whether or not the situation is present in a testing image.





# Specifying training and testing sets

Situate can take a bit of time to train models, so it's nice to identify when existing models for a particular training set can be used. To this end, there are several ways to specify the training and testing sets to be used by Situate.

#### Specifying separate directories for training/testing
#### Specifying single directory, file list
#### Specifying single directory, seed value
#### Including maximum number of testing images





# Analysis

The results of a Situate experiment are stored in the *results/* folder. There will be a folder for the experiment and individual .mat files for each of the parameterizations that were run during the experiment. 

There are several scripts available for looking at the results of the experiment.  

### Visualizing final workspaces

	situate_experiment_analysis_output_final_workspaces.m 

This script generates images displaying the final predicted bounding boxes for situation objects overlaid on the original images. It can be helpful for a subjective analysis of the quality of results. The input should be the path to a .mat file from the experiment's results directory. The script will generate a new folder in the experiment's results directory with images for each of the final workspaces included in the .mat file. 

	situate_experiment_analysis_output_final_workspaces('results/my_experiment/params1_results.mat');

### Positive instance grounding comparison

	situate_experiment_analysis.m

This script evaluates the results for a collection of test images. It can be used to compare multiple Situate parameterizations run on the same collection of test images. It produces several figures that relate the number of iterations run by a Situate parameterization to the number of situation detections made.  Results are also broken down by individual object types. 

To run this script, you need to provide the path to a directory the .mat file results for the parameterizations that you would like to compare. For example

	situate_experiment_analysis('results/my_experiment/');

The analysis will run on and compare each of the .mat files in the directory. Figures will be saved to the provided results directory.

### Image retrieval results

	situate_experiment_analysis_PR.m

This script compares the results of several parameterizations with respect to images that contain the the situation and images that do not (whereas the previous script was only concerned with generating a grounding for positive images). Situate is run on each image, producing a final workspace, which is then used to generate a single-valued *situation score*. The two evaluation metrics produces are:
- Median rank: The situation scores for a single positive image and all negative images are sorted. The rank for the positive image is the number of negative images that have a higher situation score + 1. The median rank is the median of the rank over all positive images evaluated.
- Average recall at *n*: The situation scores for a single positive image and all negative images are sorted. If the rank of the positive image is less than or equal to *n*, then it is given a recall score of 1. Otherwise, its recall score is 0. The mean recall score is taken over all positive images.

To run this script, you must provide the path to a directory containing results from a run on images that do contain the situation (path_pos), and the path to a directory containing results from a run on images that do not contain the situation (path_neg). For example

	path_pos = 'results/my_experiment_pos/';
	path_neg = 'results/my_experiment_neg/';
	[ mean_recall_at, median_rank ] = situate_experiment_alysis_PR( path_pos, path_neg );

CSV files containing the results are also written to 

	results/PR_results [current date and time]/

	
	


	




