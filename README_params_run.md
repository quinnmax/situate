# Situate running parameters

### situation model
		
The situation model defines how Situate decides where to focus attention and how to integrate findings into its understanding of the input. The situation model is specified by a learning function, an updating function, a sampling function, and a drawing function.

	"situation_model" : {
		"description" : "uniform then mixture of uniform and normal",
		"learn"  : "@(a,b) situation_models.uniform_normal_mix_fit(a,b,.5)",
		"update" : "situation_models.uniform_normal_mix_condition",
		"sample" : "situation_models.uniform_normal_mix_sample",
		"draw"   : "situation_models.uniform_normal_mix_draw"
	}

The functions have the following traces:

- learn:  
`situation_model = model_learn( situation_struct, data_in, saved_models_directory);`  
where 
  - `situation_struct` contains a cell string of objects in the situation and possible labels they might have in the training data,
  - `data_in` is a list of files used for training, and 
  - `saved_models_directory` specifies a location to look for existing models and to save the trained model.  

- update:  
`situation_model_out = model_update( situation_model_in, object_string, workspace);`  
where 
  - `situation_model_in` is the above trained model,
  - `object_string` identifies the object for which the expectations are being updated, and
  - `workspace` contains the current beliefs of Situate.

- sample:  
`sampled_box = model_sample( situation_model_in, object_string );`  
where 
  - `situation_model_in` is the above trained model,
  - `object_string` identifies the object for which the expectations are being updated, and
  - `sampled_box` is a bounding box prediction for the specified object type

- draw:  
`figure_handle = model_draw( dist_struct, object_string, viz_spec, [input_agent], [box_format_str], [is_initial_draw] );`  
where 
  - `dist_struct` contains the situation model and conditioned situation models for each object type
  - `object_string` identifies the object for which the expectations are being updated,
  - `viz_spec` can be used to specify which from among several visualizations are being requested ('xy', 'shape', 'size'),
  - `input_agent` is an optional input that specifies the current agent that should be represented in the figure. For example, if the distribution of box shapes is being displayed, the point on the density curve corresponding to the shape of the input_agent should have a distinctive point. 

The following situation models are included in `situate/+situation_models`:

- **normal**  
Situation parameters are modeled as a high dimensional normal distribution. Parameters include, for each situation object: 
  - box center positions x,y (w.r.t. image of unit area and centered at the origin), 
  - box log area (with area normalized by image size), box log aspect ratio, 
  - box width and height (normalized by square root of box area, 
  - x initial coordinate, x final coordinate, 
  - y initial coordinate, y final coordinate  (all w.r.t image of unit area and centered at origin).   

  This is an over determined set of 10 values for each object in the situation. The parameters are modeled as a single normal distribution. When sampling, unknown parameters are marginalized out and the parameters for the object of interest are sampled. Because the parameterization of a bounding box are over determined and box constraints are not enforced by the model, the box center, shape, and area are used to generate the bounding box. 

- **uniform**  
Situation parameters are modeled using a uniform distribution over the possible center positions for the box, the log aspect ratio, and log area ratio. The bounds of the uniform distribution were set by hand. The aspect ratios range from 1:4 to 4:1 and the area ratios range from 1% to 50%. 

- **uniform_normal_mix**  
This parameterization method combines the above two methods. Before any conditioning has been done, the uniform distribution is used to draw samples. Once conditioning has been done, it draws either the normal or uniform distribution based on a mixing parameter. The default mixing parameter is .5.

### pipeline options

These options define how Situate manages its pool of agents. 

- `use_direct_scout_to_workspace_pipeline`  
At its inception, Situate was a bit more stochastic. There were different agent types that were responsible for performing different tasks. Scouts evaluated internal support (image feature classification), reviewers evaluated compatibility with the workspace (likelihood), and builders were responsible for adding to the workspace (as well as removing from it).  
This complexity makes Situate hard to compare with other methods and wasn't adding much, so we've generally had it turned off. When the direct pipeline option is set to `true`, scouts over threshold evaluate a reviewer, and reviewers over threshold evaluate a builder.

- `maximum_iterations`  
This sets a hard maximum number of agent evaluations before Situate stops. When the direct pipeline option is on, the scout, reviewer, and builder are evaluated together and count as one iteration. When the direct option is not on, each agent evaluation counts as an iteration. 

- `min_number_of_scouts`  
As agents are being removed from the pool and evaluated, if the number of scouts in the pool drops below this number, more scouts will be sampled from the situation model. 
		
- `stopping_condition`  
This is a handle to a function that decides whether or not to stop during a run. The signature for the function should be:
	
		[hard_stop, soft_stop, message] = stopping_condition(workspace,agent_pool,p);  

  Where hard_stop and soft_stop are booleans. hard_stop will stop the run immediately, soft_stop will cause Situate to continue evaluating agents in the pool, but will not sample new agents if the pool drops under the min_number_of_scouts. Once the agents in the pool have all been evaluated, Situate will stop. 

  The following stopping conditions are included:

  - `situate.stopping_condition_null`  
  This is just a placeholder. Situate will only stop when the iteration limit is reached.
  - `situate.stopping_condition_situation_found`  
  This will stop Situate as soon as all situation objects have been checked into the workspace.  
  - `situate.stopping_condition_finish_up_pool`  
  This method checks to see that all situation objects are represented in the workspace and that the agent pool has no agents remaining that are adjustments to previous detections. That is to say, no potential local improvements are still in the pipe.

- `agent_urgency_defaults`  
When scouts, reviewers, and builders are evaluated stochastically, their selection is weighted using the agent_urgency_values. These are the default urgencies for each agent type. Alternative urgencies can be set in the *agent pool initialization* functions and in the *agent pool adjustment* functions. This feature has no effect when using the direct pipeline.

### classifier

The classifier is defined with *train* and *apply* functions.
The train function should have a signature of
		
	[classifier_struct] = classifier_train( situation_struct, fnames_in, saved_models_directory );

The apply function should have a signature of 
		
	[classifier_output, optional_feature_data] = classifier_apply( classifier_struct, target_class, im, box_r0rfc0cf, varargin );

- `classifier_struct` can contain anything and will be passed into the classification function for use there
- `target_class` will be a string of the situation object class for which the input should be evaluated
- `im` is the full image. `box_r0rfc0cf` is a four element vector defining the starting and ending rows and starting and ending columns of the proposed bounding box
- `varargin` is only there to catch ground truth if it's being provided (which was used when evaluating Situate with an oracle classifier)

The included classifier options are:

  - `IOU_ridge_regression`, which uses vgg16 features and a ridge regressor to estimate the IOU of the proposed box with the object type of interest.

and

  - `oracle`, which provides the actual ground truth IOU of the proposed box with the object type of interest (+ normal noise). During "training" you can pass in the mean and standard deviation of the noise added by the oracle.

### support functions

`situate/+support_functions_external` contains several scaling functions for the density of box proposals. The idea is to move from the density values (which have an unintuitive range) to a value in [0,1]. The target for this scaling was the percentile score for the density with respect to the sampling of boxes used in classifier training. These functions are of a single value, the box proposal density returned from the box sampling function. 

`situate/+support_functions_total` contains functions for mixing the internal and external support for a particular object to produce a total support value. These are functions of the internal support, the external support, and any additional values you'd like to include. For example, `situate/+support_functions_total/AUROC_based.m` uses the area under the ROC curve estimated during classifier training to weight the internal support score and external support score. If the AUROC is low, then the classifier is less reliable and external support is relied upon more.

`situate/+support_functions_situation` contains functions that convert the total support scores for objects in the workspace to a single value indicating the confidence Situate has that the situation is present and detected. As it is, the function is a simple geometric mean with a small amount of padding to distinguish between workspaces that are missing different numbers of situation objects.

### support thresholds

Support thresholds define Situate's behavior with respect to when an object is admitted to the workspace. 

- `support_thresholds.total_support_final` defines the threshold at which Situate considers an object sufficiently localized. It will be added to the workspace, used for conditioning the situation model, and, if all objects are localized with at this level, may trigger the stopping condition.

- `support_thresholds.internal_support` defines the minimum internal support score before an object can be added to the workspace.

- `support_thresholds.internal_support_retain` defines an internal support threshold for which a scout will remain in the agent pool rather than being removed after evaluation. If an agent has high internal support, but does not consistent with the current workspace, retaining it in the pool makes it available for consideration if the workspace changes.

- `support_thresholds.total_support_provisional` defines a minimum total support that will admit an object to the workspace, but will not consider the object sufficiently localized. Situate will still look for the object, and will not consider the situation detected, but will use the information to condition the situation model.

### agent pool initialization function

At the start of a Situate run, the agent pool can be initialized using several included functions.

`situate.agent.pool_initialize_default`  
Does no special pre-processing. The minimum number of scouts are sampled and added to the pool.

`situate.agent.pool_initialize_covering`  
The pool starts with a collection of scouts that create a covering over the image. Hard-coded parameters define the sizes, shapes, and spacing of the covering.

`situate.agent.pool_initialize_covering_rcnn_like`  
Starts with the covering described above, applies the specified classifier and agent-adjustment models, then initializes the pool with the highest scoring boxes for each object of interest.

`situate.agent.pool_initialize_rcnn`  
Can be used to include a list of bounding boxes generated from an external method. 

### agent pool adjustment rules

`agent_pool_adjustment_rule` is a function handle to a function that will be run after each agent evaluation. It will take the current agent pool and return an updated agent pool. Depending on the agent adjustment rules employed below, this function can be used to keep Situate from entering a local search loop.

### agent adjustment model

The agent adjustment model is a function that takes a scout and the current agent pool and returns an updated agent pool. The model has an activation logic function of the scout, a training function, and an application function. 

The included agent adjustment models are based on bounding-box regression, which uses the output of vgg16 to predict whether the bounding box would have a higher IOU with its underlying object if it were: wider or thinner, and taller or shorter. Based on the regressors prediction, a modified agent is added to the pool. In general, this method is useful for engaging in local search based on the findings of an agent. 

Another included functions perform stochastic local search. 

### temperature adjustment rules

Temperature is a property of the workspace and the current iteration count that can be used in other functions to define their behavior. The temperature adjustment rule defines a starting value and an update rule. Currently, the temperature is not used.

