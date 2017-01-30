


%% try to get path in order 
% check a little that sub directories are included

    gui_or_experiment_path = fileparts(which('situate_experiment_script'));
    cd( gui_or_experiment_path );
    addpath(fullfile(gui_or_experiment_path));
    addpath(genpath(fullfile(gui_or_experiment_path, 'tools')));
    warning('off');



%% define experiment settings 
%
% These are some basic settings for the experimental run, relating to
% whether or not you want to use the GUI, where to save the experiment
% results, and how many images for training and testing.

    experiment_settings = [];
    experiment_settings.use_gui = false;
    
    experiment_settings.title               = 'local search test';
    experiment_settings.situations_struct   = situate.situation_definitions();
    experiment_settings.situation           = 'dogwalking'; 
    
    % num_folds and training/testing images to use per fold
    %   -num_folds won't matter if gui is on.
    %   -If testing_data_max or testing_data_min are set to [], then as much
    %   as possible will be used, given the available data and the number
    %   of folds.
    experiment_settings.num_folds           = 1;  
    experiment_settings.testing_data_max    = 25;  % per fold
    experiment_settings.training_data_max   = []; 
    % total testing images is num_folds * testing_data_max
    
    % (won't happen if gui is on)
    experiment_settings.run_analysis_after_completion = true;
    
    % run situate on the training data, 
    % save off both the oracle and classifier data,
    % 
    % if true, it should do it with the actual IOU deciding when something
    % is committed to the workspace, and the CNN value should just be
    % recorded. this is definitely not the case.
    experiment_settings.perform_situate_run_on_training_data = false;
    
    % save's all crops, for all images, all methods, all folds to the
    % output data mat. be careful. don't use on big runs.
    experiment_settings.save_all_crops = false;
    
    % results directory
    %   results won't be saved if gui is on
    experiment_settings.results_directory = fullfile('/Users/',char(java.lang.System.getProperty('user.name')),'/Desktop/', [experiment_settings.title '_' datestr(now,'yyyy.mm.dd.HH.MM.SS')]);
    if ~exist(experiment_settings.results_directory,'dir') && ~experiment_settings.use_gui, mkdir(experiment_settings.results_directory); display(['made results directory ' experiment_settings.results_directory]); end



%% set the data directory 
%
% situate_data_path points to a directory containing the images and label 
% files for your experiment. 
% 
% situate_situation_definitions contains a list of possible data paths for
% each situation. As it is, the first of these paths that exists will be
% used. If none of them exist, there will be a directory selection popup.
%
% Alternatively, you can skip all of this and just specify your own directory
% contiaining images and label files with:
% situate_data_path = '/Users/me/Desktop/something_something/';

    try
        data_path = experiment_settings.situations_struct.(experiment_settings.situation).possible_paths{ find(cellfun( @(x) exist(x,'dir'), experiment_settings.situations_struct.(experiment_settings.situation).possible_paths ),1,'first')};
    catch
        while ~exist('data_path','var') || isempty(data_path) || ~isdir(data_path)
            h = msgbox( ['Select directory containing images of ' experiment_settings.situation] );
            uiwait(h);
            data_path = uigetdir(pwd); 
        end
    end



%% define your training testing splits 
%
% These define how we get our training/testing splits, and lets us control
% the seed value used at the beginning of each run. The benefit of
% controlled training/testing splits is that we can re-use the same
% classifiers. The benefit of controlling the testing seed is that we can
% reproduce specific runs if they seem to do something interesting.
%
% split_arg is either an integer or a directory 
%
%   If split_arg is an integer, it will be used as a seed value for the 
%   randomly generated splits. The value will be stored in
%   p_conditions.seed_train
%
%   If split_arg is a directory, it will look for training-testing split files
%   in that directory and load them up. Split files in the directory should
%   have names like:
%       *_split_01_test.txt, *_split_01_train.txt
%       *_split_02_test.txt, *_split_02_train.txt ...
%   and should contain a line separated list of label file names (with no 
%   path) to use in each split. p_conditions.seed_train will be empty if
%   you use a directory.

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

    % seed test
        % seed_test = RandStream.shuffleSeed;  % generates a seed based on current time, stores it into p_structures
        seed_test = 1;
        
    

%% define situate parameters: shared 
%
% These are the shared settings across the different experimental
% condtions. They can be modified in the next section to compare different
% running conditions, but in general, these are the things that we haven't
% been changing very much.
    
    p = situate.parameters_initialize();
    
    p.rcnn_boxes = false;
    
    % classifier
        % p.classification_method  = 'IOU-oracle';
        % p.classification_method  = 'noisy-oracle';
        p.classification_method  = 'CNN-SVM'; % uses Rory's cnn code
        % p.classification_method  = 'HOG-SVM';
        
    % pipeline
        p.num_iterations = 2000;         
        p.use_direct_scout_to_workspace_pipe        = true; % hides stochastic agent stuff a bit, more comparable to other methods     
        p.refresh_agent_pool_after_workspace_change = true; % prevents us from evaluating agents from a stale distribution
        
    % inhibition and padding
        % p.inhibition_method = 'blackman';                     
        % p.dist_xy_padding_value = .05;    
        % p.inhibition_intensity = .5;      
        
    % support and check-in
        p.external_support_function = @(x) sigmoid(   2 * p.image_redim_px * ( x - (1/p.image_redim_px) )     );
        % p.total_support_function = @(internal,external) .75 * internal + .25 * external;
        p.total_support_function = @(internal,external) .5 * internal + .5 * external;
        
        p.thresholds.internal_support                   = .50; % scout -> reviewer threshold
        p.thresholds.total_support_provisional          = .50; % workspace entry, provisional (search continues)
        p.thresholds.total_support_final                = .50; % workspace entry, final (search (maybe) ends) depends on p.situation_objects_urgency_post

    % stopping conditions
        p.stopping_condition = @situate.stopping_condition_null; % use all iterations, don't stop on detection
        %p.stopping_condition = @stopping_condition_situation_found;
        
    % tweaking
        p.local_search_activation_logic = @(cur_agent) cur_agent.support.total > p.thresholds.total_support_provisional;
        % p.local_search_function = [];
        p.local_search_function = @spawn_local_scouts;
        
        
    % set up visualization parameters
        if experiment_settings.use_gui
            p.show_visualization_on_iteration           = true;
            p.show_visualization_on_iteration_mod       = 1;
            p.show_visualization_on_workspace_change    = false;
            p.show_visualization_on_end                 = true;
            p.start_paused                              = true;
            % use_training_testing_split_files = false;
        else
            p.show_visualization_on_iteration           = false;
            p.show_visualization_on_iteration_mod       = 1; % moot
            p.show_visualization_on_workspace_change    = false;
            p.show_visualization_on_end                 = false;
            p.start_paused                              = false;
        end
    
    % add the seed values to p
        p.seed_test  = seed_test;
        p.seed_train = seed_train;
        
    % if running a training data collection run, 
    % tell situate to save off CNN scores, even if using IOU-oracle as the
    % classifier
        if experiment_settings.perform_situate_run_on_training_data
            p.save_CNN_score = true;
        else
            p.save_CNN_score = false;
        end
        
    % add the situation information to the p structure
        p.situation_objects                 = experiment_settings.situations_struct.(experiment_settings.situation).situation_objects;
        p.situation_objects_possible_labels = experiment_settings.situations_struct.(experiment_settings.situation).situation_objects_possible_labels;
        p.situation_objects_urgency_pre     = experiment_settings.situations_struct.(experiment_settings.situation).object_urgency_pre;
        p.situation_objects_urgency_post    = experiment_settings.situations_struct.(experiment_settings.situation).object_urgency_post;
    
    % the default values for these are uniform for pre, and zeros for post
    switch experiment_settings.situation
        case 'dogwalking'
            p.situation_objects_urgency_pre.(  'dogwalker') = 1.0;
            p.situation_objects_urgency_pre.(  'dog'      ) = 1.0;
            p.situation_objects_urgency_pre.(  'leash'    ) = 1.0;
            p.situation_objects_urgency_post.( 'dogwalker') = 1.0;
            p.situation_objects_urgency_post.( 'dog'      ) = 1.0;
            p.situation_objects_urgency_post.( 'leash'    ) = 1.0;
        case 'pingpong'            
            p.situation_objects_urgency_pre.(  'table'  )   = 0.1;
            p.situation_objects_urgency_pre.(  'net'    )   = 0.1;
            p.situation_objects_urgency_pre.(  'player1')   = 1.0;
            p.situation_objects_urgency_pre.(  'player2')   = 1.0;
            p.situation_objects_urgency_post.( 'table'  )   = 0.1;
            p.situation_objects_urgency_post.( 'net'    )   = 0.1;
            p.situation_objects_urgency_post.( 'player1')   = 0.1;
            p.situation_objects_urgency_post.( 'player2')   = 0.1;
        otherwise
            % Default urgencies will be used. Find them in:
            %   situate_situation_definitions 
            
    end



%% define siutate parameters: experimental conditions 
%
% These are modifications to the shared situate parameters defined above.
% Anything not modified here will use those settings.
%
% If using the gui, the first setting will be used to populate the gui 
% settings popup, the rest will be ignored.

    p_conditions = [];
    p_conditions_descriptions = {};
  
%     description = 'Random search';
%     temp = p;
%     temp.location_method_before_conditioning            = 'uniform';
%     temp.location_method_after_conditioning             = 'uniform';
%     temp.box_method_before_conditioning                 = 'independent_uniform_log_aa';
%     temp.box_method_after_conditioning                  = 'independent_uniform_log_aa';
%     temp.location_sampling_method_before_conditioning   = 'sampling';
%     temp.location_sampling_method_after_conditioning    = 'sampling';
%     temp.use_temperature                                = false;
%     temp.description = description;
%     if isempty( p_conditions ), p_conditions = temp; else p_conditions(end+1) = temp; end
    
%     description = 'Random search with learned box distributions';
%     temp = p;
%     temp.location_method_before_conditioning            = 'uniform';
%     temp.location_method_after_conditioning             = 'uniform';
%     temp.box_method_before_conditioning                 = 'independent_normals_log_aa';
%     temp.box_method_after_conditioning                  = 'independent_normals_log_aa';
%     temp.location_sampling_method_before_conditioning   = 'sampling';
%     temp.location_sampling_method_after_conditioning    = 'sampling';
%     temp.use_temperature                                = false;
%     temp.description = description;
%     if isempty( p_conditions ), p_conditions = temp; else p_conditions(end+1) = temp; end
%     
%     description = 'Situate old sampling';
%     temp = p;
%     temp.location_method_before_conditioning            = 'uniform';
%     temp.location_method_after_conditioning             = 'mvn_conditional';
%     temp.box_method_before_conditioning                 = 'independent_normals_log_aa';
%     temp.box_method_after_conditioning                  = 'conditional_mvn_log_aa';
%     temp.location_sampling_method_before_conditioning   = 'sampling';
%     temp.location_sampling_method_after_conditioning    = 'sampling';
%     temp.use_temperature                                = false;
%     temp.description = description;
%     if isempty( p_conditions ), p_conditions = temp; else p_conditions(end+1) = temp; end
%
%     description = 'Situate new sampling';
%     temp = p;
%     temp.location_method_before_conditioning            = 'uniform';
%     temp.location_method_after_conditioning             = 'mvn_conditional';
%     temp.box_method_before_conditioning                 = 'independent_normals_log_aa';
%     temp.box_method_after_conditioning                  = 'conditional_mvn_log_aa';
%     temp.location_sampling_method_before_conditioning   = 'sampling';
%     temp.location_sampling_method_after_conditioning    = 'sampling_mvn_fast';
%     temp.use_temperature                                = false;
%     temp.description = description;
%     if isempty( p_conditions ), p_conditions = temp; else p_conditions(end+1) = temp; end
%    
    
    
    description = 'Situate, use local search';
    temp = p;
    temp.location_method_before_conditioning            = 'uniform';
    temp.location_method_after_conditioning             = 'mvn_conditional';
    temp.box_method_before_conditioning                 = 'independent_normals_log_aa';
    temp.box_method_after_conditioning                  = 'conditional_mvn_log_aa';
    temp.location_sampling_method_before_conditioning   = 'sampling';
    temp.location_sampling_method_after_conditioning    = 'sampling';
    temp.use_temperature                                = false;
    temp.description = description;
    temp.total_support_function = @(internal,external) .5 * internal + .5 * external;
temp.local_search_activation_logic = @(cur_agent) cur_agent.support.total > p.thresholds.total_support_provisional;
    if isempty( p_conditions ), p_conditions = temp; else p_conditions(end+1) = temp; end
    
    description = 'Situate, no local search';
    temp = p;
    temp.location_method_before_conditioning            = 'uniform';
    temp.location_method_after_conditioning             = 'mvn_conditional';
    temp.box_method_before_conditioning                 = 'independent_normals_log_aa';
    temp.box_method_after_conditioning                  = 'conditional_mvn_log_aa';
    temp.location_sampling_method_before_conditioning   = 'sampling';
    temp.location_sampling_method_after_conditioning    = 'sampling';
    temp.use_temperature                                = false;
    temp.description = description;
    temp.total_support_function = @(internal,external) .5 * internal + .5 * external;
temp.local_search_activation_logic = @(cur_agent) false;
    if isempty( p_conditions ), p_conditions = temp; else p_conditions(end+1) = temp; end
    
    % validate the options before we start running with them
    %    this just checks that methods_before and method_after type stuff is
    %    set to something present in the method_options arrays. just to
    %    catch typos and stuff here.
    assert( all( arrayfun( @situate.parameters_validate, p_conditions ) ) );



%% run the experiment 

    situate.experiment_helper(experiment_settings, p_conditions, data_path, split_arg);



%% run the analysis 

    if experiment_settings.run_analysis_after_completion && ~experiment_settings.use_gui
        %situate_experiment_analysis( experiment_settings.results_directory );
        situate_experiment_analysis( experiment_settings.results_directory );
    end


