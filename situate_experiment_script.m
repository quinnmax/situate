


%% Initial setup (path, how to define splits, rng seed values )

    script_directory = fileparts(mfilename('fullpath'));
    if isempty(script_directory), script_directory = fileparts(which('situate_experiment_script')); end
    cd( script_directory );
    run( fullfile(script_directory, 'matconvnet', 'matlab', 'vl_setupnn.m' ) );
    addpath( genpath( fullfile(script_directory, 'tools') ) );
    
    p = situate.parameters_initialize();
    experiment_settings = [];
    
    % seed train
        % split_arg = now; % randomly generated with time-based seed value
        % split_arg = 1; % randomly generated with seed value 1
        % split_arg = uigetdir(pwd); % pick one in the gui
        split_arg = 'split_validation/'; % validation set (hard)
        % split_arg = 'split_test_stanford/';
        % split_arg = 'split_test/';
        
        if ischar(split_arg)
            seed_train = [];
        elseif isnumeric(split_arg)
            seed_train = split_arg;
        end
        
        % re: split_arg
        %   This defines how we get our training/testing splits will be generated.
        %   The split arg can take on a few different values for differing behaviors.
        %
        %   numeric: will be the seed value in generating a random split
        %
        %   directory string: will look in the directory for some files that define
        %       some specific, pre-existing splits. this is useful if you want to use
        %       an already trained classifier and want to remain consistent with its
        %       training set. The naming convention for the files in this directory
        %       are:
        %           *_split_01_test.txt, *_split_01_train.txt
        %           *_split_02_test.txt, *_split_02_train.txt ...
        %       The file names in the split file are line separated and contain no path

    % seed test
        seed_test = RandStream.shuffleSeed;  % generates a seed based on current time, stores it into p_structures
        %seed_test = 1;
    
      
        
%% Experiment settings ( title, viz, num images,folds ) 
%
% These are some basic settings for the experimental run, relating to
% whether or not you want to use the GUI, where to save the experiment
% results, and how many images for training and testing.

    experiment_settings.title               = 'dogwalking, validation set experiment';
    experiment_settings.situations_struct   = situate.situation_definitions();
    experiment_settings.situation           = 'dogwalking';  % look in experiment_settings.situations_struct to see the options
    
    % note: use [] if you want to use all available data
    experiment_settings.folds               = [1];  % list the folds, not how many. ie, 2:4
    experiment_settings.testing_data_max    = [1];   % per fold, empty is all available
    experiment_settings.training_data_max   = []; 
    
    experiment_settings.use_gui                         = false;
    experiment_settings.use_parallel                    = false;
    experiment_settings.run_analysis_after_completion   = false;
    
    % additional visualization options
    
        if experiment_settings.use_gui
            p.viz_options.on_iteration          = true;
            p.viz_options.on_iteration_mod      = 1;
            p.viz_options.on_workspace_change   = false;
            p.viz_options.on_end                = true;
            p.viz_options.start_paused          = true;
        else
            p.viz_options.on_iteration          = false;
            p.viz_options.on_iteration_mod      = 1;
            p.viz_options.on_workspace_change   = false;
            p.viz_options.on_end                = false;
            p.viz_options.start_paused          = false;
        end
      
    % lazy output results directory setting
    
    if strcmp(computer,'GLNXA64')
        experiment_settings.results_directory = fullfile('results',[experiment_settings.title '_' datestr(now,'yyyy.mm.dd.HH.MM.SS')]);                                                                                          
    elseif strcmp(computer,'MACI64')
        experiment_settings.results_directory = fullfile('results', [experiment_settings.title '_' datestr(now,'yyyy.mm.dd.HH.MM.SS')]);
    else
        error('don''t know the machine');
    end
    if ~exist(experiment_settings.results_directory,'dir') && ~experiment_settings.use_gui, mkdir(experiment_settings.results_directory); display(['made results directory ' experiment_settings.results_directory]); end

 
    
%% Situation definition

 % add the situation information to the p structure
    
        p.situation_objects                 = experiment_settings.situations_struct.(experiment_settings.situation).situation_objects;
        p.situation_objects_possible_labels = experiment_settings.situations_struct.(experiment_settings.situation).situation_objects_possible_labels;
        switch experiment_settings.situation
            case 'dogwalking'
                
                % p.situation_objects_urgency_pre  = experiment_settings.situations_struct.('dogwalking').object_urgency_pre;
                % p.situation_objects_urgency_post = experiment_settings.situations_struct.('dogwalking').object_urgency_post;
                
                p.situation_objects_urgency_pre  = 1.00;
                p.situation_objects_urgency_post = 0.25;
                
                % p.situation_objects_urgency_pre.(  'dogwalker') = 1.00;
                % p.situation_objects_urgency_pre.(  'dog'      ) = 1.00;
                % p.situation_objects_urgency_pre.(  'leash'    ) = 1.00;
                % p.situation_objects_urgency_post.( 'dogwalker') = 0.25;
                % p.situation_objects_urgency_post.( 'dog'      ) = 0.25;
                % p.situation_objects_urgency_post.( 'leash'    ) = 0.25;

            case 'pingpong' 
                
                p.situation_objects_urgency_pre   = experiment_settings.situations_struct.('pingpong').object_urgency_pre;
                p.situation_objects_urgency_post = experiment_settings.situations_struct.('pingpong').object_urgency_post;
                
                % p.situation_objects_urgency_pre.(  'table'  )   = 0.1;
                % p.situation_objects_urgency_pre.(  'net'    )   = 0.1;
                % p.situation_objects_urgency_pre.(  'player1')   = 1.0;
                % p.situation_objects_urgency_pre.(  'player2')   = 1.0;
                % p.situation_objects_urgency_post.( 'table'  )   = 0.1;
                % p.situation_objects_urgency_post.( 'net'    )   = 0.1;
                % p.situation_objects_urgency_post.( 'player1')   = 0.1;
                % p.situation_objects_urgency_post.( 'player2')   = 0.1;
                
            otherwise
                p.situation_objects_urgency_pre     = experiment_settings.situations_struct.(experiment_settings.situation).object_urgency_pre;
                p.situation_objects_urgency_post    = experiment_settings.situations_struct.(experiment_settings.situation).object_urgency_post;
        end
        

    
%% Situate parameters: situation model 
%
% These are the shared settings across the different experimental
% condtions. They can be modified in the next section to compare different
% running conditions, but in general, these are the things that we haven't
% been changing very much within an experimental run
    
    % situation model
    
        situation_model_description = 'uniform normal mix';
        
        switch situation_model_description
            
            case 'normal'
                p.situation_model.learn = @situation_models.normal_fit;        
                    % takes: p, cellstr of training images 
                    % returns: model object

                p.situation_model.update = @situation_models.normal_condition; 
                    % takes: model object, workspace 
                    % returns: model object

                p.situation_model.sample = @situation_models.normal_sample;  
                    % takes: model object, object type str 
                    % returns: sampled box r0rfc0cf, density of sample
                    %   if passed a box, should just return the density of
                    %   that box wrt the current situation model
               
                p.situation_model.draw = @situation_models.normal_draw;
                    % takes: situation_model, object_string, what_to_draw_string
                    % returns: nothing, just draws a figure
                    %   what_to_draw can be 'xy', 'shape', 'size'
                    
            case 'uniform'
                p.situation_model.learn  = @situation_models.uniform_fit;
                p.situation_model.update = @situation_models.uniform_condition;
                p.situation_model.sample = @situation_models.uniform_sample;
                p.situation_model.draw   = @situation_models.uniform_draw;
                
            case 'uniform location normal box'
                p.situation_model.learn  = @situation_models.uniform_location_normal_box_fit;
                p.situation_model.update = @situation_models.uniform_location_normal_box_condition;
                p.situation_model.sample = @situation_models.uniform_location_normal_box_sample;
                p.situation_model.draw   = @situation_models.uniform_location_normal_box_draw;
                
            case 'uniform normal mix'
                probability_of_uniform_after_conditioning = .5;
                p.situation_model.learn = @(a,b) situation_models.uniform_normal_mix_fit(a,b,probability_of_uniform_after_conditioning);        
                    % takes: p, cellstr of training images 
                    % returns: model object

                p.situation_model.update = @situation_models.uniform_normal_mix_condition; 
                    % takes: model object, workspace 
                    % returns: model object

                p.situation_model.sample = @situation_models.uniform_normal_mix_sample;  
                    % takes: model object, object type str 
                    % returns: sampled box r0rfc0cf, density of sample
                    %   if passed a box, should just return the density of
                    %   that box wrt the current situation model
               
                p.situation_model.draw = @situation_models.uniform_normal_mix_draw;
                    % takes: situation_model, object_string, what_to_draw_string
                    % returns: nothing, just draws a figure
                    %   what_to_draw can be 'xy', 'shape', 'size'
                    
            case 'uniform then normal'
                p.situation_model.learn = @situation_models.uniform_then_normal_fit;        
                    % takes: p, cellstr of training images 
                    % returns: model object

                p.situation_model.update = @situation_models.uniform_then_normal_condition; 
                    % takes: model object, workspace 
                    % returns: model object

                p.situation_model.sample = @situation_models.uniform_then_normal_sample;  
                    % takes: model object, object type str 
                    % returns: sampled box r0rfc0cf, density of sample
                    %   if passed a box, should just return the density of
                    %   that box wrt the current situation model
               
                p.situation_model.draw = @situation_models.uniform_then_normal_draw;
                    % takes: situation_model, object_string, what_to_draw_string
                    % returns: nothing, just draws a figure
                    %   what_to_draw can be 'xy', 'shape', 'size'
                    
            case 'salience normal'
                p.situation_model.learn = @situation_models.salience_normal_fit;        
                    % takes: p, cellstr of training images 
                    % returns: model object

                p.situation_model.update = @situation_models.salience_normal_condition; 
                    % takes: model object, workspace 
                    % returns: model object

                p.situation_model.sample = @situation_models.salience_normal_sample;  
                    % takes: model object, object type str 
                    % returns: sampled box r0rfc0cf, density of sample
                    %   if passed a box, should just return the density of
                    %   that box wrt the current situation model
               
                p.situation_model.draw = @situation_models.salience_normal_draw;
                    % takes: situation_model, object_string, what_to_draw_string
                    % returns: nothing, just draws a figure
                    %   what_to_draw can be 'xy', 'shape', 'size'
                
            case 'none'
                assert(0==1);
                
                
            otherwise
                assert(0==1);
        end
  
    
        
%% Situate parameters: classifier 
        
        classifier_description = 'IOU ridge regression';
        
        switch classifier_description
            case 'noisy oracle'
                p.classifier_load_or_train          = @classifiers.oracle_train; 
                p.classifier_apply                  = @classifiers.oracle_apply;
                p.classifier_saved_models_directory = 'default_models/';
            case 'cnn svm'
                p.classifier_load_or_train          = @classifiers.cnnsvm_train; 
                p.classifier_apply                  = @classifiers.cnnsvm_apply;
                p.classifier_saved_models_directory = 'default_models/';
            case 'IOU ridge regression'
                p.classifier_load_or_train = @classifiers.IOU_ridge_regression_train;
                p.classifier_apply = @classifiers.IOU_ridge_regression_apply;
                p.classifier_saved_models_directory = 'default_models/';
            otherwise
                assert(1==0);
        end
        
        
        
        % classifier_struct = classifier_load_or_train( p, fnames_in, saved_models_directory )
        %
        % inputs
        %   p: 
        %       the parameters structure for situate 
        %       (used for situation objects, labels for those objects, etc )
        %   fnames_lb_train: 
        %       cellstr of training image label files 
        %   model_directory: 
        %       directory for saving off models.
        %       also looks here for an already trainined model with matching training set/description
        %
        % outputs
        %   classifier_struct that is passed into the
        %   classifier_apply function

        
        
        % [classifier_score, gt_iou] = classifier_apply( classifier_struct, target_class_string, image, box_r0rfc0cf, label_file );
        %
        % inputs
        %   classifier_struct:
        %       struct with fields:
        %           classes: cell string with the known classes
        %               the models (with a specific object of interest) are stored in a cell array 
        %               in the same order as the object class strings are listed here
        %           classifier_model: cell of outputs from the load_or_train function for each class
        %           fnames_lb_train: data used to train the model
        %           description: description of the model
        %   target_class_string:
        %       string with the target class. should match one entry from classifier_struct.classes
        %   image:
        %       [0 255] rgb
        %   box_r0rfc0cf:
        %       the bounding box for the region to classify
        %   label_file:
        %       if you want the ground truth iou, then pass in the label struct as well. 
        %       should be no problem if excluded
        %
        % outputs
        %   classifier_score:
        %       in the range [0,1] (roughly, not enforced)
        %   gt_iou:
        %       the ground truth intersection over union.
        %       also in [0,1], only available if the label file was included
     
        
        
%% Situate parameters: iterations, pipeline

% some basic parameters that define how Situate runs. How many iterations (max), how many scouts are
% being used, how Situate will decide when to stop.

    % pipeline
    
        p.num_iterations = 1000;         
        p.num_scouts = 10;
        p.use_direct_scout_to_workspace_pipe = true; % hides stochastic agent stuff a bit     
        
    % stopping conditions
    
        % [stop_now] = stopping_condition_function(  workspace, agent_pool, p );
    
        %p.stopping_condition = @situate.stopping_condition_null;                % use all iterations, don't stop on detection
        %p.stopping_condition = @situate.stopping_condition_situation_found;     % stop once the situation is checked-in
        p.stopping_condition = @situate.stopping_condition_finish_up_pool;      % stop once the situation is checked-in and residual agents have been evaluated
        
        
        
%% Situate parameters: support functions 
    
        external_support_function = 'atan fit';
        total_support_function    = 'regression experiment';
        
        % define how to calculate external support (ie, compatibility between a proposed entry to
        % the workspace and the existing entries) and total support (a combination of the internal
        % support and external support).
        %
        % external support is a function of the sample density. the functions here were
        % bootstrapped. a validation run gave us an idea of the sample densities. we had a target
        % function in mind that we defined over the observed range, and we fit a function mapping
        % the observed densities to the target output function.
        % 
        % the output function was defined with the following intentions:
        %   samples before conditioning had occurred would be low in the range of possible values
        %   samples after conditioning could be below the value from unconditioned samples
        %   samples after conditioning should have an effective range that differentiates between 
        
        switch external_support_function
            case 'atan fit'
                % bootstrapped and fit to the following target function of density percentile: 
                %   x_target_function = [ 0  .5  .9   1 ];
                %   y_target_function = [ 0   0   1   1 ];
                % where x is the density percentile from a validation experiment run.
                % upto the 50th percentile, roughly zero external support
                % from 50th to 90th, active region, linear increase in external support
                % from 90th to 100th, saturation, external support 1
                activation_function = @(x,b) b(1) + b(2) * atan( b(3) * (x-b(4)) );
                b = [ 0.0237, 0.6106, 4.4710e-12, -0.3192 ];
                p.external_support_function = @(x) activation_function(x,b);
            case 'logistic_normalized_dist'
                p.external_support_function = @(x) logistic( log(x), .1); 
                % based on just poking at density values from training data. 
                % used for continuous, unit area, centered at origin distribution
            case 'jointly learned external and total'
                % same data as 'atan fit', but instead of fitting to a hand drawn target function,
                % the parameters that make up the external and total support functions were learned
                % in one go to fit the gt_iou. should perform better, but in reality, it was about
                % the same and much less interpretable.
                b = [0.9266   -0.0583    0.0453   -4.6040e-13    0.0063; ...
                     0.9177    0.0065    0.0654    1.7392e-12    0.0025; ...
                     0.7588   31.4216  -14.1538    8.1987e-15   -0.1110  ];
                activation_function = @(x,b) b(1) + b(2) * atan( b(3) * (x-b(4)) );
                p.external_support_function = {};
                p.external_support_function{1} = @(x) activation_function(x,[0 1 b(1,4) b(1,5)]);
                p.external_support_function{2} = @(x) activation_function(x,[0 1 b(2,4) b(2,5)]);
                p.external_support_function{3} = @(x) activation_function(x,[0 1 b(3,4) b(3,5)]);
            case 'identity'
                p.external_support_function = @(x) x;
            otherwise
                error('unrecognized external support function');
        end
        
        switch total_support_function
            case 'internal_only'
                p.total_support_function    = @(internal,external) 1.0 * internal + 0.0 * external;
            case 'even'
                p.total_support_function    = @(internal,external) 0.5 * internal + 0.5 * external;
            case 'mostly internal'
                p.total_support_function    = @(internal,external) 0.8 * internal + 0.2 * external;
            case 'product'
                p.total_support_function    = @(internal,external) internal * external;
            case 'regression experiment'
                % bootstrap re-estimation based on validation set run
                b = [   0.1210    0.8053   -0.0033    0.0220; ...
                        0.0568    0.8975   -0.0001   -0.0204; ...
                        0.1383    0.5683    0.1271    0.1949 ];
                p.total_support_function    = {};
                p.total_support_function{1} = @(internal,external) b(1,1) + b(1,2) * internal + b(1,3) * external + b(1,4) * internal * external;
                p.total_support_function{2} = @(internal,external) b(2,1) + b(2,2) * internal + b(2,3) * external + b(2,4) * internal * external;
                p.total_support_function{3} = @(internal,external) b(3,1) + b(3,2) * internal + b(3,3) * external + b(3,4) * internal * external;
            case 'jointly learned external and total'
                b = [0.9266   -0.0583    0.0453   -4.6040e-13    0.0063; ...
                     0.9177    0.0065    0.0654    1.7392e-12    0.0025; ...
                     0.7588   31.4216  -14.1538    8.1987e-15   -0.1110  ];
                activation_function = @(x,b) b(1) + b(2) * atan( b(3) * (x-b(4)) );
                p.total_support_function = {};
                p.total_support_function{1} = @(internal,external) b(1,1) * internal + b(1,2) * external + b(1,3) * internal * external;
                p.total_support_function{2} = @(internal,external) b(2,1) * internal + b(2,2) * external + b(2,3) * internal * external;
                p.total_support_function{3} = @(internal,external) b(3,1) * internal + b(3,2) * external + b(3,3) * internal * external;
            otherwise
                error('unrecognized total support function');
        end
           
        
        
%% Situate parameters: thresholds
    
        check_in_thresholds = 'parameter experiment findings';
        
        switch check_in_thresholds
            case 'IOU'
                p.thresholds.internal_support          = .25; % scout -> reviewer threshold
                p.thresholds.total_support_provisional = .25; % workspace entry, provisional (search continues)
                p.thresholds.total_support_final       = .50; % workspace entry, final (search (maybe) ends) depends on p.situation_objects_urgency_post
            case 'logreg_experiment'
                p.thresholds.internal_support          = .15; % scout -> reviewer threshold
                p.thresholds.total_support_provisional = .15; % workspace entry, provisional (search continues)
                p.thresholds.total_support_final       = .35; % workspace entry, final (search (maybe) ends) depends on p.situation_objects_urgency_post
            case 'custom'
                p.thresholds.internal_support          = .25; % scout -> reviewer threshold
                p.thresholds.total_support_provisional = .25; % workspace entry, provisional (search continues)
                p.thresholds.total_support_final       = .75; % workspace entry, final (search (maybe) ends) depends on p.situation_objects_urgency_post
            case 'parameter experiment findings'
                p.thresholds.internal_support          = .2;   % scout -> reviewer threshold
                p.thresholds.total_support_provisional = inf;   % workspace entry, provisional (search continues)
                p.thresholds.total_support_final       = .5625; % workspace entry, final (search (maybe) ends) depends on p.situation_objects_urgency_post
                % p.thresholds.total_support_final = .5625; % was best when using 'bounding box regression two-tone per-object'
                % p.thresholds.total_support_final = .625;  % was best when using 'bounding box regression two-tone with decay'
            otherwise
                error('unrecognized check-in method');
        end
     
        
        
%% Situate parameters: adjustment model
    
        adjustment_model_description = 'bounding box regression two-tone per-object';
    
        switch adjustment_model_description
            
            case 'bounding box regression'
                p.adjustment_model_activation_logic     = @(cur_agent,workspace,p) situate.adjustment_model_activation_logic( cur_agent, workspace, p.thresholds.internal_support, 1.0 );
                box_adjust_training_threshold           = .1;
                p.adjustment_model_setup                = @(a,b,c) box_adjust.train(a,b,c,box_adjust_training_threshold);
                p.adjustment_model_apply                = @box_adjust.apply;
            case 'bounding box regression two-tone with decay'
                p.adjustment_model_activation_logic     = @(cur_agent,workspace,p) situate.adjustment_model_activation_logic( cur_agent, workspace, .3, 1.0 );
                box_adjust_training_thresholds          = [.1 .6];
                model_selection_threshold               = .5; % set via validation set experiments
                p.adjustment_model_setup                = @(a,b,c) box_adjust.two_tone_train(a,b,c,box_adjust_training_thresholds, model_selection_threshold);
                p.adjustment_model_apply                = @box_adjust.two_tone_w_decay_apply; % decay value of .9 is hard coded in box_adjust.apply_w_decay 
            case 'bounding box regression two-tone'
                p.adjustment_model_activation_logic     = @(cur_agent,workspace,p) situate.adjustment_model_activation_logic( cur_agent, workspace, p.thresholds.internal_support, 1.0 );
                box_adjust_training_thresholds          = [.1 .6];
                model_selection_threshold               = .5; % set via validation set experiments
                p.adjustment_model_setup                = @(a,b,c) box_adjust.two_tone_train(a,b,c,box_adjust_training_thresholds, model_selection_threshold);
                p.adjustment_model_apply                = @box_adjust.two_tone_apply;
            case 'bounding box regression two-tone per-object'
                % set via validation set experiment
                p.adjustment_model_activation_logic     = cell(1,length(p.situation_objects));
                p.adjustment_model_activation_logic{1}  = @(cur_agent,workspace,p) situate.adjustment_model_activation_logic( cur_agent, workspace, .1, 1.0 );
                p.adjustment_model_activation_logic{2}  = @(cur_agent,workspace,p) situate.adjustment_model_activation_logic( cur_agent, workspace, .2, 1.0 );
                p.adjustment_model_activation_logic{3}  = @(cur_agent,workspace,p) situate.adjustment_model_activation_logic( cur_agent, workspace, .3, 1.0 );
                box_adjust_training_thresholds          = [.1 .6];
                model_selection_threshold               = .5; % set via validation set experiments
                p.adjustment_model_setup                = @(a,b,c) box_adjust.two_tone_train(a,b,c,box_adjust_training_thresholds, model_selection_threshold);
                p.adjustment_model_apply                = @box_adjust.two_tone_apply;
            case 'local agent search'
                p.adjustment_model_activation_logic     = @(cur_agent,workspace,p) local_agents.activation_logic( cur_agent, workspace, .65, 1.0 ); % set via validation set experiments                                                                     
                p.adjustment_model_setup                = @(a,b,c,d) [];
                p.adjustment_model_apply                = @local_agents.generate_agents;
            case 'none'
                p.adjustment_model_activation_logic     = @(cur_agent,a,b) false;
                p.adjustment_model_setup                = @(a,b,c,d) [];
                p.adjustment_model_apply                = @(cur_agent) assert(1==0);
        end
        
   
    
    % seed values get saved in p
    
        p.seed_test  = seed_test;
        p.seed_train = seed_train;
        
        
        
%% Situate parameters: temperature stuff (nothing yet) ) 

    p.temperature = [];
    p.temperature.initial = 100;
    p.temperature.update = @(x) 100; % do nothing, anywhere
        
    
    
%% Experimental conditions 
%
% These are modifications to the shared situate parameters defined above.
% Anything not modified here will use those settings.
%
% If using the gui, the first setting will be used to populate the gui 
% settings popup, the rest will be ignored.

    p_conditions = [];
    p_conditions_descriptions = {};
    
    description = 'normal location and box, box adjust';
    temp = p;
    temp.description = description;
    if isempty( p_conditions ), p_conditions = temp; else p_conditions(end+1) = temp; end
    
%     description = 'uniform location and box, no box adjust';
%     temp = p;
%     temp.description = description;
%     temp.situation_model.learn  = @situation_models.uniform_fit;
%     temp.situation_model.update = @situation_models.uniform_condition;
%     temp.situation_model.sample = @situation_models.uniform_sample;
%     temp.situation_model.draw   = @situation_models.uniform_draw;
%     temp.adjustment_model_activation_logic = @(cur_agent,a,b) false;
%     temp.adjustment_model_setup            = @(a,b,c,d) [];
%     temp.adjustment_model_apply            = @(cur_agent) assert(1==0);
%     temp.total_support_function            = @(internal,external) 1.0 * internal + 0 * external;
%     if isempty( p_conditions ), p_conditions = temp; else p_conditions(end+1) = temp; end
%     
%     description = 'uniform location and box, box adjust';
%     temp = p;
%     temp.description = description;
%     temp.situation_model.learn  = @situation_models.uniform_fit;
%     temp.situation_model.update = @situation_models.uniform_condition;
%     temp.situation_model.sample = @situation_models.uniform_sample;
%     temp.situation_model.draw   = @situation_models.uniform_draw;
%     temp.total_support_function = @(internal,external) 1.0 * internal + 0 * external;
%     if isempty( p_conditions ), p_conditions = temp; else p_conditions(end+1) = temp; end
%     
%     description = 'normal location and box, no box adjust';
%     temp = p;
%     temp.description = description;
%     temp.adjustment_model_activation_logic = @(cur_agent,a,b) false;
%     temp.adjustment_model_setup            = @(a,b,c,d) [];
%     temp.adjustment_model_apply            = @(cur_agent) assert(1==0);
%     if isempty( p_conditions ), p_conditions = temp; else p_conditions(end+1) = temp; end
    
  
    
%% Data directory 
%
% situate_data_path should point to a directory containing the images and label 
% files for your experiment. 
%
% situate.situation_definitions contains the default paths that situate
% will search. if it doesn't find anything, it'll ask in a popup

    try
        possible_path_ind = find(cellfun( @(x) exist(x,'dir'), experiment_settings.situations_struct.(experiment_settings.situation).possible_paths ),1,'first');
        data_path = experiment_settings.situations_struct.(experiment_settings.situation).possible_paths{ possible_path_ind };s
    catch
        while ~exist('data_path','var') || isempty(data_path) || isequal(data_path,0) || ~isdir(data_path)
            h = msgbox( ['Select directory containing images of ' experiment_settings.situation] );
            uiwait(h);
            data_path = uigetdir(pwd); 
        end
    end

    

%% Run the experiment 

    if experiment_settings.use_gui || ~experiment_settings.use_parallel
        situate.experiment_helper(experiment_settings, p_conditions, data_path, split_arg);
    else
        situate.experiment_helper_par(experiment_settings, p_conditions, data_path, split_arg);
    end



%% Run the analysis 

    if experiment_settings.run_analysis_after_completion && ~experiment_settings.use_gui
        %situate_experiment_analysis( experiment_settings.results_directory );
        situate_experiment_analysis( experiment_settings.results_directory );
    end


