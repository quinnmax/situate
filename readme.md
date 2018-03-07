


# Situate

Situate is a system for active grounding of situations in images.     
[edit: link to icsc paper]



# Running Situate

### Experiment parameters
	
The *experiment parameters* file specifies:
- the situation definition
- the Situate running parameters
- the training and testing images
- visualization settings
	
example: "parameters_experiment_dogwalking_viz.json"
	
#### Situation definition
	
The *situation definition* file specifies 
- the situation objects that make up the situation
- a mapping from possible labels (found in training data) to the situation objects

example: "situation_definitions/dogwalking.json"

#### Situate running parameters
	
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

Defining a new situation requires a file that defines the situation and set of positive training example images that have labels specifying the relevant objects in each image. 

### Situation definition file

Situation definition files are in JSON format. They include a description of the situation and a list of constituent objects. The constituent objects have a list of labels that may be present in the training data. 

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

The relationships between the constituent objects are inferred from the training data. Each training image should have a label file that specifies tight bounding boxes for situation objects in the image.

Labels can be generated with the tool:
	
	labels_generate('my_image_directory/');

These images and label files will be used to train:
- the situation model
- visual classifiers [edit:cite]
- bounding box regressors [edit:cite]

The reliability of the individual classifiers can be estimated and used to weight the classifiers contribution to situation detections.



# Specifying training and testing sets

Situate can take a bit of time to train models, so it's nice to identify when existing models for a particular training set can be used. To this end, there are several ways to specify the training and testing sets to be used by Situate.

Specifying images for training and testing is done with the following variables in an *experiment parameters* file:
	
	"directory_train"                  : "",
	"directory_test"                   : "",
	"training_testing_split_directory" : "",
	"num_folds"                        : "",
	"specific_folds"                   : [],
	"max_testing_images"               : "",
	"testing_seed"                     : ""

Together, these over determine the specification of training and testing images, so below are a few things one might want to do, and how they would be specified.

#### Separate directories for training/testing

To train on all images in a directory (say, folder_a/) and test on all images in a separate directory (folder_b/), the parameters should be set as below:

	"directory_train"                  : "folder_a/",
	"directory_test"                   : "folder_b/",
	"training_testing_split_directory" : "",
	"num_folds"                        : "",
	"specific_folds"                   : [],
	"max_testing_images"               : "",
	"testing_seed"                     : ""

#### Specifying single directory, file list

If all images are in a single directory and the training and testing images are specified by lists of image names in a file, the parameters should be set as below:

	"directory_train"                  : "folder_a/",
	"directory_test"                   : "folder_a/",
	"training_testing_split_directory" : "data_splits/example_split/",
	"num_folds"                        : "",
	"specific_folds"                   : [],
	"max_testing_images"               : "",
	"testing_seed"                     : ""

The folder *data_splits/example_split/* should contain at least two text files with the naming format 

	[*]fnames_split_[n]_train.txt
	[*]fnames_split_[n]_test.txt

where *n* indicates which split these files specify, and contents that include one file name per line without path information. For example:

	situate_fnames_split_1_train.txt

	situation_image_001.jpg
	situation_image_002.jpg
	situation_image_003.jpg

and

	situate_fnames_split_1_test.txt

	situation_image_004.jpg
	situation_image_005.jpg

#### Specifying separate directories and including file lists

If you would like to use a subset of the available training and testing data present in separate directories, you can specify both separate folders and a folder contain file lists.  Parameters should be set as below:

	"directory_train"                  : "folder_a/",
	"directory_test"                   : "folder_b/",
	"training_testing_split_directory" : "data_splits/example_split/",
	"num_folds"                        : "",
	"specific_folds"                   : [],
	"max_testing_images"               : "",
	"testing_seed"                     : ""

#### Specifying specific folds to run

If there are files that define multiple folds, then the variable *specific_folds* can be used to specify which folds should be run. For example, if there are five folds defined that have image file lists and you want to run only the 2nd and 4th folds, then the parameters should be set as below

	"directory_train"                  : "folder_a/",
	"directory_test"                   : "folder_a/",
	"training_testing_split_directory" : "data_splits/example_split/",
	"num_folds"                        : "",
	"specific_folds"                   : [2,4],
	"max_testing_images"               : "",
	"testing_seed"                     : ""

#### Specifying single directory, seed value

If all images are in a single directory, and you'd like to have situate generate a split between training and testing images, then you have several options. 

You can specify the number of folds, which in turn defines the number of training images per fold. That is, if you set *num_folds* to 3, then 2/3 of images will be used for training, 1/3 for testing. Note: if *num_folds* is set to 1, then 25% of the data is used for testing. 

 parameters should be set as below:

	"directory_train"                  : "folder_a/",
	"directory_test"                   : "folder_a/",
	"training_testing_split_directory" : "",
	"num_folds"                        : "",
	"specific_folds"                   : [],
	"max_testing_images"               : "",
	"testing_seed"                     : ""

When the same folder is specified for training and testing and no split files are provided, split files will be generated and saved in 
*data_splits/[situation description]_[time stamp]/*

#### Including maximum number of testing images

For any of the above methods, a maximum number of testing images to run on can be specified and will simply limit the number of images that Situate will run on. It will not change how many images are used for training. For example, if there are 100 images included in the testing image directory,

	"max_testing_images" : 10,

will cause Situate to run on only the first 10 images in that directory.



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
	[ mean_recall_at, median_rank ] = situate_experiment_analysis_PR( path_pos, path_neg );

CSV files containing the results are also written to 

	results/PR_results [current date and time]/

	
	


	




