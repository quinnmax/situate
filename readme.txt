

Running

	define an experiment with an experiment parameters file.
	eg, parameters_experiment_viz.json

		in this file you will specify the situation definition file. eg, 
		"situation_definitions/dogwalking.json"

		as well as a situate parameters file. eg, 
		"parameterization_situate_default.json"

		as well as training and testing image directories. eg,
		"directory_train" : "/Users/Max/Documents/images/DogWalking_PortlandSimple_train/",
		"directory_test"  : "/Users/Max/Documents/images/DogWalking_PortlandSimple_train/",

		as well as several running parameters. eg,
			"use_parallel"					: 0, 
			"run_analysis_after_completion"	: 0,
			"num_folds" 					: 1,
			"max_testing_images" 			: "",
			

			
	run an experiment from the situate directory with
		situate.experiment_run( 'parameters_experiment_viz.json' );







Learning a new situation

	data
		divide into training and testing directories
		generate labels for training data

	situation definition file
		{ 
			"situation":{
				"description" : "blue_red_balls",
				
				"blue_ball" : {
					"possible_labels" : [
						"blue_ball_big",
						"blue_ball_small"],
					"urgency_pre"  : "1.0",
					"urgency_post" : ".25"
				},

				"red_ball" : {
					"possible_labels" : [
						"red_ball_big",
						"red_ball_small"],
					"urgency_pre"  : "1.0",
					"urgency_post" : ".25"
				}

				"possible_training_data_paths" : [
					"/possible_path_1/",
					"/possible_path_2/",
					"/possible_path_3/" ],
			}
		}

		put situation definition json into situate/situation_definitions
	




