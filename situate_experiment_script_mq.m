


%% Initial setup (path, how to define splits, rng seed values )


    script_directory = fileparts(mfilename('fullpath'));
    if isempty(script_directory), script_directory = fileparts(which('situate_experiment_script_mq')); end
    cd( script_directory );
    run( fullfile(script_directory, 'matconvnet', 'matlab', 'vl_setupnn.m' ) );
    addpath( genpath( fullfile(script_directory, 'tools') ) );
    
    p = situate.parameters_initialize();
    experiment_settings = [];
    
    % seed train
        % split_arg = now;
        % split_arg = 1;
        % split_arg = uigetdir(pwd);
        split_arg = 'default_split/';
        
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

    experiment_settings.title               = 'dogwalking, rebaseline';
    experiment_settings.situations_struct   = situate.situation_definitions();
    experiment_settings.situation           = 'dogwalking';  % look in experiment_settings.situations_struct to see the options
    
    % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % 
    experiment_settings.use_gui = false;
    % note: when doing a GUI run, the following won't happen
    %   run_analysis_after_completion,
    %   saving off results
    %   using more than the first experimental condition
    %   using more than the first data fold
    % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % 
    
    % note: use [] if you want to use all available data
    experiment_settings.num_folds           = 1;  
    experiment_settings.testing_data_max    = 100;  % per fold
    experiment_settings.training_data_max   = []; 
    
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
        
    experiment_settings.run_analysis_after_completion = true;
      
    experiment_settings.results_directory = fullfile('/Users/',char(java.lang.System.getProperty('user.name')),'/Desktop/', [experiment_settings.title '_' datestr(now,'yyyy.mm.dd.HH.MM.SS')]);
    if ~exist(experiment_settings.results_directory,'dir') && ~experiment_settings.use_gui, mkdir(experiment_settings.results_directory); display(['made results directory ' experiment_settings.results_directory]); end

    
    
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
            
            case 'uniform normal mix'
                 p.situation_model.learn = @situation_models.uniform_normal_mix_fit;        
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
        
         % classifier requirements
    
            % [classifier_model] = classifier_load_or_train( p, fnames_in, saved_models_directory )
            % inputs
            %   p: the parameters structure for situate
            %   fnames_lb_train: cellstr of training image label files 
            %   model_directory: path to location that main contain already trainined models, and if not, 
            %       the destination for saving the trained model
            % outputs
            %   classifier_model structure that is passed into the
            %   classifier_apply function
        
            % [classifier_score, gt_iou] = classifier_apply( classifier_model_struct, target_class_string, image, box_r0rfc0cf, label_file );
            % inputs
            %   classifier_model_struct
            %       struct with fields:
            %           model cell: each with an .apply function that takes image arrays
            %           classes: cell string with the classes associated with the models, in the order of the models in their cell array
            %           fnames_lb_train: which has the training label files that were used
            %           description: just a string, should be used for matching on load in the future           
            %   target_class_string
            %       string with the target class. should match one entry from classifier_model_struct.classes
            %   image
            %       can be [0,1] or [0 255]
            %   box_r0rfc0cf
            %       the bounding box for the region to classify
            %   label_file
            %       if you want the ground truth iou, then pass in the
            %       label struct as well
            % outputs
            %   classifier_score in the range [0,1]
            %   the ground truth IOU ( also in [0,1] ) is only available if
            %   the label structure was provided
        
        
        
%% Situate parameters: iterations, pipeline
%
% These are the shared settings across the different experimental
% condtions. They can be modified in the next section to compare different
% running conditions, but in general, these are the things that we haven't
% been changing very much within an experimental run
        
    p.num_iterations = 2000;         

    % pipeline
    
        p.use_direct_scout_to_workspace_pipe             = true; % hides stochastic agent stuff a bit, more comparable to other methods     
        p.agent_pool_cleanup.on_workspace_change         = true;
        p.agent_pool_cleanup.on_object_of_interest_found = true;
        
    % stopping conditions
    
        p.stopping_condition = @situate.stopping_condition_null; % use all iterations, don't stop on detection
        %p.stopping_condition = @situate.stopping_condition_situation_found; % go until all situation objects are checked-in over p.thresholds.total_support_final
        
        
        
%% Situate parameters: support functions 
    
        external_support_function = 'logistic_normalized_dist'; % from sample density to a 0,1 range
        
        total_support_function = 'mostly internal';
        
        switch external_support_function
            case 'logistic_normalized_dist'
                p.external_support_function = @(x) logistic( log(x), .1); 
                % based on just poking at density values from training data. 
                % used for continuous, unit area, centered at origin distribution
            case 'logistic for discretized distribution'
                assert(1==0);
            case 'identity'
                p.external_support_function = @(x) x;
            otherwise
                error('unrecognized external support function');
        end
        
        switch total_support_function
            case 'internal_only'
                p.total_support_function    = @(internal,external) 1 * internal;
            case 'even'
                p.total_support_function    = @(internal,external) .5 * internal + .5 * external;
            case 'mostly internal'
                p.total_support_function    = @(internal,external) .8 * internal + .2 * external;
            case 'product'
                p.total_support_function    = @(internal,external) internal * external;
            case 'logreg_experiment'
                % version learned from logistic regression experiment
                p.total_support_function    = {};
                p.total_support_function{1} = @(internal,external) -4.05 + 3.01 * external + 2.00 * internal + -0.01 * internal*external;
                p.total_support_function{2} = @(internal,external) -3.82 + 2.55 * external + 1.33 * internal +  0.80 * internal*external;
                p.total_support_function{3} = @(internal,external) -2.58 + 1.09 * external + 2.53 * internal + -0.77 * internal*external;
            otherwise
                error('unrecognized total support function');
        end
           
        
        
%% Situate parameters: thresholds
    
        check_in_thresholds = 'custom';
        
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
                p.thresholds.total_support_provisional = .5; % workspace entry, provisional (search continues)
                p.thresholds.total_support_final       = .8; % workspace entry, final (search (maybe) ends) depends on p.situation_objects_urgency_post
            otherwise
                error('unrecognized check-in method');
        end
     
        
        
%% Situate parameters: adjustment model
    
        adjustment_model_description = 'none';
    
        switch adjustment_model_description
            
            case 'bounding box regression'
                p.adjustment_model_activation_logic = @(cur_agent) cur_agent.support.total > p.thresholds.total_support_provisional;
                p.adjustment_model_setup            = @box_adjust.train;
                p.adjustment_model_apply            = @box_adjust.apply;
            case 'local agent search'
                p.adjustment_model_activation_logic = @(cur_agent) cur_agent.support.total > p.thresholds.total_support_provisional;
                p.adjustment_model_setup            = @(a,b,c,d) [];
                p.adjustment_model_apply            = @situate.spawn_local_scouts;
            case 'none'
                p.adjustment_model_activation_logic = @(cur_agent) false;
                p.adjustment_model_setup            = @(a,b,c,d) [];
                p.adjustment_model_apply            = @(cur_agent) assert(1==0);
        end
        
    % add the situation information to the p structure
    
        p.situation_objects                 = experiment_settings.situations_struct.(experiment_settings.situation).situation_objects;
        p.situation_objects_possible_labels = experiment_settings.situations_struct.(experiment_settings.situation).situation_objects_possible_labels;
        switch experiment_settings.situation
            case 'dogwalking'
                
                %p.situation_objects_urgency_pre  = experiment_settings.situations_struct.('dogwalking').object_urgency_pre;
                %p.situation_objects_urgency_post = experiment_settings.situations_struct.('dogwalking').object_urgency_post;
                
                p.situation_objects_urgency_pre.(  'dogwalker') = 1.0;
                p.situation_objects_urgency_pre.(  'dog'      ) = 1.0;
                p.situation_objects_urgency_pre.(  'leash'    ) = 1.0;
                p.situation_objects_urgency_post.( 'dogwalker') =  .25;
                p.situation_objects_urgency_post.( 'dog'      ) =  .25;
                p.situation_objects_urgency_post.( 'leash'    ) =  .25;
                
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
    
%     description = 'Situate, default condition';
%     temp = p;
%     temp.description = description;
%     if isempty( p_conditions ), p_conditions = temp; else p_conditions(end+1) = temp; end
    
    description = 'Situate, adjustment model: box adjust';
    temp = p;
    temp.description = description;
    temp.adjustment_model_activation_logic = @(cur_agent) cur_agent.support.total > p.thresholds.internal_support & cur_agent.support.total < .9;
    temp.adjustment_model_setup            = @box_adjust.train;
    temp.adjustment_model_apply            = @box_adjust.apply;
    if isempty( p_conditions ), p_conditions = temp; else p_conditions(end+1) = temp; end
    
    description = 'Situate, adjustment model: local agents';
    temp = p;
    temp.description = description;
    temp.adjustment_model_activation_logic = @(cur_agent) cur_agent.support.total > p.thresholds.total_support_provisional;
    temp.adjustment_model_setup            = @(a,b,c,d) [];
    temp.adjustment_model_apply            = @situate.spawn_local_scouts;
    if isempty( p_conditions ), p_conditions = temp; else p_conditions(end+1) = temp; end
    
    description = 'Situate, adjustment model: none';
    temp = p;
    temp.description = description;
    temp.adjustment_model_activation_logic = @(cur_agent) false;
    temp.adjustment_model_setup            = @(a,b,c,d) [];
    temp.adjustment_model_apply            = @(cur_agent) assert(1==0);
    if isempty( p_conditions ), p_conditions = temp; else p_conditions(end+1) = temp; end


    
%% Data directory 
%
% situate_data_path should point to a directory containing the images and label 
% files for your experiment. 
%
% situate.situation_definitions contains the default paths that situate
% will search. if it doesn't find anything, it'll ask in a popup

    try
        possible_path_ind = find(cellfun( @(x) exist(x,'dir'), experiment_settings.situations_struct.(experiment_settings.situation).possible_paths ),1,'first');
        data_path = experiment_settings.situations_struct.(experiment_settings.situation).possible_paths{ possible_path_ind };
    catch
        while ~exist('data_path','var') || isempty(data_path) || ~isdir(data_path)
            h = msgbox( ['Select directory containing images of ' experiment_settings.situation] );
            uiwait(h);
            data_path = uigetdir(pwd); 
        end
    end

    

%% Run the experiment 

    situate.experiment_helper(experiment_settings, p_conditions, data_path, split_arg);



%% Run the analysis 

    if experiment_settings.run_analysis_after_completion && ~experiment_settings.use_gui
        %situate_experiment_analysis( experiment_settings.results_directory );
        situate_experiment_analysis( experiment_settings.results_directory );
    end


