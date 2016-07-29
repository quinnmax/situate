


%% try to get path in order
% check a little that sub directories are included

    situate_gui_or_experiment_path = fileparts(which('situate_experiment_script'));
    cd( situate_gui_or_experiment_path );
    addpath(fullfile(situate_gui_or_experiment_path));
    addpath(genpath(fullfile(situate_gui_or_experiment_path, 'tools')));

   
   
%% define experiment settings

    experiment_settings = [];
    experiment_settings.use_gui = false;
    
    experiment_settings.title               = 'experiment_title';
    experiment_settings.situations_struct   = situate_situation_definitions();
    experiment_settings.situation           = 'dogwalking'; 
    
    % (won't matter if gui is on)
    experiment_settings.results_directory = fullfile('/Users/',char(java.lang.System.getProperty('user.name')),'/Desktop/', [experiment_settings.title '_' datestr(now,'yyyy.mm.dd.HH.MM.SS')]);
    if ~exist(experiment_settings.results_directory,'dir') && ~experiment_settings.use_gui, mkdir(experiment_settings.results_directory); display(['made results directory ' experiment_settings.results_directory]); end

    % (won't matter if gui is on)
    experiment_settings.num_folds           = 1;
    experiment_settings.testing_data_max    = 5; % empty will use as much as possible given the number of folds.
    experiment_settings.training_data_max   = 30; % empty will use as much as possible given the number of folds. (less than 30 migth cause problems)
    
    % (won't matter if gui is on)
    experiment_settings.run_analysis_after_completion = true;
    

    
%% set the data directory
% situate_data_path should point to a directory containing the images and 
% label files for your experiment. 
% 
% As it is, it'll grab the first existing path from the list of 
% possible paths specified in the situation-definition. You can add 
% directories to that list in situate_situation_definitions.
%
% You can also just skip all of this and specify your own directory
% contiaining images and label files.

    % situate_data_path = '/Users/me/Desktop/something_something/';
    try
        situate_data_path = experiment_settings.situations_struct.(experiment_settings.situation).possible_paths{ find(cellfun( @(x) exist(x,'dir'), experiment_settings.situations_struct.(experiment_settings.situation).possible_paths ),1,'first')};
    catch
        while ~exist('situate_data_path','var') || isempty(situate_data_path) || ~isdir(situate_data_path)
            h = msgbox( ['Select directory containing images of ' experiment_settings.situation] );
            uiwait(h);
            situate_data_path = uigetdir(pwd); 
        end
    end
    


%% define your training testing splits
% split_arg controls how training-testing splits are generated
%
% If split_arg = [], it will pick a random seed and generate random
% training-testing splits based on the number of training-testing images
% and folds defined above.
%
% If split_arg is a number, that number will be used as a seed value for
% the randomly generated splits. This makes it easy to reproduce runs if
% you don't want to re-train models or something.
%
% If split_arg is a directory, it will look for training-testing split files
% in that directory and load them up. The filenames included in the lists
% should for label files and should be stripped of path information,
% should have one file name per line, and should have titles like:
%    *_split_01_test.txt, *_split_01_train.txt
%    *_split_02_test.txt, *_split_02_train.txt ...

    % split_arg = [];                   
    split_arg = 1;                      
    % split_arg = uigetdir(pwd);        
    % split_arg = 'default_splits/';
    

    
    
%% define situate parameters: shared
    
    p = situate_parameters_initialize();
    
    p.rcnn_boxes = false;
    
    % classifier
        p.classification_method  = 'IOU-oracle';
        %p.classification_method  = 'CNN-SVM'; % uses Rory's cnn code
        %p.classification_method  = 'HOG-SVM';
        
    % pipeline
        % p.num_scouts = 10; % sets how many agents the pool will be initialized with, and how many it will be filled back up to. should probalby be called min_agent_pool_size
        p.num_iterations = 1000;         
        p.use_direct_scout_to_workspace_pipe        = true; % hides stochastic agent stuff a bit, more comparable to other methods     
        p.refresh_agent_pool_after_workspace_change = true; % prevents us from evaluating agents from a stale distribution
        
    % object priority
        p.object_type_priority_before_example_is_found = 1;  
        p.object_type_priority_after_example_is_found  = 0;  % 0 means never look for a better object box after something is sufficiently found
    
    % inhibition and padding
        % p.inhibition_method = 'blackman';                     
        % p.dist_xy_padding_value = .05;    
        % p.inhibition_intensity = .5;      
        
    % check-in and tweaking
        p.use_box_adjust = false; % based on Evan's classifier based move selection
        p.spawn_nearby_scouts_on_provisional_checkin = false; % based on Max's agent based local search
        % p.thresholds.internal_support = .25; % scout -> reviewer threshold
        % p.thresholds.total_support_provisional = .25; (search continues)
        % p.thresholds.total_support_final       = .5;  (search ends)

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
    
    
    
%% define siutate parameters: experimental conditions
%
% these are modifications to the shared experiment_settings.situation parameters defined above.
% anything not specified will use those settings.
%
% if using the gui, 
% the first setting will be used to populate the gui settings popup, 
% the rest will be ignored

    p_conditions = [];
    p_conditions_descriptions = {};
    
    description = 'salience, normals, learned mvn';
    temp = p;
    temp.location_method_before_conditioning            = 'salience_blurry';
    temp.location_method_after_conditioning             = 'mvn_conditional_and_salience';
    temp.box_method_before_conditioning                 = 'independent_normals_log_aa';
    temp.box_method_after_conditioning                  = 'conditional_mvn_log_aa';
    temp.location_sampling_method_before_conditioning   = 'sampling';
    temp.location_sampling_method_after_conditioning    = 'sampling';
    temp.description = description;
    if isempty( p_conditions ), p_conditions = temp; else p_conditions(end+1) = temp; end

    description = 'uniform, uniform, uniform';
    temp = p;
    temp.location_method_before_conditioning            = 'uniform';
    temp.location_method_after_conditioning             = 'uniform';
    temp.box_method_before_conditioning                 = 'independent_uniform_log_aa';
    temp.box_method_after_conditioning                  = 'independent_uniform_log_aa';
    temp.location_sampling_method_before_conditioning   = 'sampling';
    temp.location_sampling_method_after_conditioning    = 'sampling';
    temp.description = description;
    if isempty( p_conditions ), p_conditions = temp; else p_conditions(end+1) = temp; end
    
    % validate the options before we start running with them
    %    this just checks that methods_before and method_after type stuff is
    %    set to something present in the method_options arrays. just to
    %    catch typos and stuff here.
    assert( all( arrayfun( @situate_parameters_validate, p_conditions ) ) );

   
   
   %% run the experiment
   
   situate_experiment_helper(experiment_settings, p_conditions, situate_data_path, split_arg);
   
   
   
   %% run the analysis

    if experiment_settings.run_analysis_after_completion && ~experiment_settings.use_gui
        situate_experiment_analysis( experiment_settings.results_directory );
    end


