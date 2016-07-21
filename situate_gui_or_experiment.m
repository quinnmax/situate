
    

    use_gui = false;
    % alternative is experiment mode
    
    situation = 'dogwalking';
    % situation = 'handshaking';
    % situation = 'pingpong';
    % situation = 'dogwalking_no_leash';
    % situation = 'dogwalking_just_dog';
    
    
    experiment_title = 'experiment_high_thresholds';

    use_training_testing_split_files = false;
    
    num_folds = 10;
    testing_data_max  = []; % empty will use as much as possible given the folds
    training_data_max = []; % empty will use as much as possible given the folds. if you use less than 50, the multivariate normals will bust
    
    rng(1);
    %rng('shuffle');

    
    
%% set up shared situate parameteres
    
    p = situate_parameters_initialize();
    
    p.rcnn_boxes = false;
    
    p.use_nn_model = false;
    
    % classifier
        p.classification_method = 'IOU-oracle';
        % p.classification_method = 'CNN-SVM'; % uses Rory's cnn code
        
    % pipeline
        p.use_direct_scout_to_workspace_pipe = true; % hides stochastic agent stuff a bit, more comparable to other methods     
        p.refresh_agent_pool_after_workspace_change = true; % prevents us from evaluating agents from a stale distribution
    
    % object priority
        p.object_type_priority_before_example_is_found = 1;  
        p.object_type_priority_after_example_is_found  = 0;  % 0 means never look for a better object box after something is sufficiently found
    
    % inhibition and padding
        % p.inhibition_method = 'blackman';                     
        % p.dist_xy_padding_value = .05;    
        % p.inhibition_intensity = .5;      
        p.num_iterations = 1000;         
    
    % check-in and tweaking
        p.use_box_adjust = false; % based on Evan's classifiers
        % p.internal_support_threshold = .25; % scout -> reviewer threshold
        p.total_support_threshold_1  = .9; % workspace provisional check-in threshold (search continues)
        p.total_support_threshold_2  = .95;  % sufficient detection threshold (ie, good enough to end search for that oject)

    % set up visualization parameters
    if use_gui
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
    
    
    
%% define situations
% edit: this should be editable from the gui form

switch situation
    
     case 'dogwalking'
        p.situation_objects =  { 'dogwalker', 'dog', 'leash' };
        p.situation_objects_possible_labels = {...
            {'dog-walker back', 'dog-walker front', 'dog-walker my-left', 'dog-walker my-right'},...
            {'dog back', 'dog front', 'dog my-left', 'dog my-right'},...
            {'leash-/', 'leash-\'}};
        possible_paths = { ...
            '/Users/mm/Desktop/PortlandSimpleDogWalking/', ...
            '/stash/mm-group/evan/crop_learn/data/PortlandSimpleDogWalking/', ...
            '/Users/Max/Documents/MATLAB/data/situate_images/PortlandSimpleDogWalking/', ...
            '/home/rsoiffer/Desktop/Matlab/DogWalkingData/PortlandSimpleDogWalking/'};
        data_path = possible_paths{ find(cellfun(@(x) exist(x,'dir'),possible_paths), 1 )};
        
    case 'dogwalking_no_leash'
        p.situation_objects =  { 'dogwalker', 'dog' };
        p.situation_objects_possible_labels = {...
            {'dog-walker back', 'dog-walker front', 'dog-walker my-left', 'dog-walker my-right'},...
            {'dog back', 'dog front', 'dog my-left', 'dog my-right'} };
        possible_paths = { ...
            '/Users/mm/Desktop/PortlandSimpleDogWalking/', ...
            '/stash/mm-group/evan/crop_learn/data/PortlandSimpleDogWalking/', ...
            '/Users/Max/Documents/MATLAB/data/situate_images/PortlandSimpleDogWalking/', ...
            '/home/rsoiffer/Desktop/Matlab/DogWalkingData/PortlandSimpleDogWalking/'};
        data_path = possible_paths{ find(cellfun(@(x) exist(x,'dir'),possible_paths), 1 )};
        
    case 'dogwalking_just_dog'
        p.situation_objects =  { 'dog' };
        p.situation_objects_possible_labels = {...
            {'dog back', 'dog front', 'dog my-left', 'dog my-right'} };
        possible_paths = { ...
            '/Users/mm/Desktop/PortlandSimpleDogWalking/', ...
            '/stash/mm-group/evan/crop_learn/data/PortlandSimpleDogWalking/', ...
            '/Users/Max/Documents/MATLAB/data/situate_images/PortlandSimpleDogWalking/', ...
            '/home/rsoiffer/Desktop/Matlab/DogWalkingData/PortlandSimpleDogWalking/'};
        data_path = possible_paths{ find(cellfun(@(x) exist(x,'dir'),possible_paths), 1 )};
    
    case 'handshaking'       
        p.situation_objects =  { 'person_my_left', 'handshake', 'person_my_right' };
        p.situation_objects_possible_labels = {...
            {'person-my-left'}, ...
            {'handshake'}, ...
            {'person-my-right'}};
        possible_paths = { ...
            '/Users/Max/Documents/MATLAB/data/situate_images/HandshakeLabeled/', ...
            'C:\Users\LiFamily\Desktop\2016 ASE\HandshakeLabeled',...
            '/fakepath/justchecking'};
        data_path = possible_paths{ find(cellfun(@(x) exist(x,'dir'),possible_paths), 1 )};
        
    case 'pingpong'
        p.situation_objects =  { 'table','net','player1','player2' };
        p.situation_objects_possible_labels = {...
            {'table'}, ...
            {'net'}, ...
            {'player-front','player-back','player-my-left','player-my-right'}, ...
            {'player-front','player-back','player-my-left','player-my-right'}};
        possible_paths = { ...
            '/Users/Max/Documents/MATLAB/data/situate_images/PingPongLabeled/Labels/', ...
            'C:\Users\LiFamily\Desktop\2016 ASE\PingPongLabeled'};
        data_path = possible_paths{ find(cellfun(@(x) exist(x,'dir'),possible_paths), 1 )};
        
end
    
% set directories for potentialy saved models
possible_paths_cnn_svm_models = { ...
    '/Users/Max/Documents/MATLAB/data/situate_saved_models/cnn_svm/', ...
    'saved_models_cnn_svm/'};
saved_model_path_cnn_svm = possible_paths_cnn_svm_models{ find(cellfun(@(x) exist(x,'dir'),possible_paths_cnn_svm_models), 1, 'first' )};

possible_paths_box_adjust_models = {...
    '/stash/mm-group/evan/saved/models/box_adjust' ...
    '/Users/Max/Documents/MATLAB/data/situate_saved_models/box_adjust/', ...
    'saved_models_box_adjust/'};
saved_model_path_box_adjust = possible_paths_box_adjust_models{ find(cellfun(@(x) exist(x,'dir'),possible_paths_box_adjust_models), 1, 'first' )};

possible_paths_hog_svm_models = {...
    '/Users/Max/Documents/MATLAB/data/situate_saved_models/hog_svm/', ...
    'saved_models_hog_svm/'};
saved_model_path_hog_svm = possible_paths_hog_svm_models{ find(cellfun(@(x) exist(x,'dir'),possible_paths_hog_svm_models), 1, 'first' )};

% rcnn models don't use any of our training data, so the model isn't
% adjusted over folds



%% define experimental settings
% if using the gui, only the first one will end up being used. 
% the first setting will be used to populate the gui settings popup

    p_conditions = [];
    p_conditions_descriptions = {};
    
%     description = 'rcnn boxes, uniform location, learned boxes, learned conditional models';
%     temp = p;
%     temp.rcnn_boxes = true;
%     temp.location_method_before_conditioning            = 'uniform';
%     temp.location_method_after_conditioning             = 'mvn_conditional';
%     temp.box_method_before_conditioning                 = 'independent_normals_log_aa';
%     temp.box_method_after_conditioning                  = 'conditional_mvn_log_aa';
%     temp.location_sampling_method_before_conditioning   = 'sampling';
%     temp.location_sampling_method_after_conditioning    = 'sampling';
%     p_conditions_descriptions{end+1} = description;
%     if isempty( p_conditions ), p_conditions = temp; else p_conditions(end+1) = temp; end
%     
%     description = 'rcnn boxes, uniform location, uniform boxes, no conditioning';
%     temp = p;
%     temp.rcnn_boxes = true;
%     temp.location_method_before_conditioning            = 'uniform';
%     temp.location_method_after_conditioning             = 'uniform';
%     temp.box_method_before_conditioning                 = 'independent_uniform_log_aa';
%     temp.box_method_after_conditioning                  = 'independent_uniform_log_aa';
%     temp.location_sampling_method_before_conditioning   = 'sampling';
%     temp.location_sampling_method_after_conditioning    = 'sampling';
%     p_conditions_descriptions{end+1} = description;
%     if isempty( p_conditions ), p_conditions = temp; else p_conditions(end+1) = temp; end
    

    
    description = 'salience, normals, learned mvn';
    temp = p;
    temp.location_method_before_conditioning            = 'salience_blurry';
    temp.location_method_after_conditioning             = 'mvn_conditional_and_salience';
    temp.box_method_before_conditioning                 = 'independent_normals_log_aa';
    temp.box_method_after_conditioning                  = 'conditional_mvn_log_aa';
    temp.location_sampling_method_before_conditioning   = 'sampling';
    temp.location_sampling_method_after_conditioning    = 'sampling';
    p_conditions_descriptions{end+1} = description;
    if isempty( p_conditions ), p_conditions = temp; else p_conditions(end+1) = temp; end

%     description = 'salience, normals, learned mvn (no provisional)';
%     temp = p;
%     temp.location_method_before_conditioning            = 'salience_blurry';
%     temp.location_method_after_conditioning             = 'mvn_conditional_and_salience';
%     temp.box_method_before_conditioning                 = 'independent_normals_log_aa';
%     temp.box_method_after_conditioning                  = 'conditional_mvn_log_aa';
%     temp.location_sampling_method_before_conditioning   = 'sampling';
%     temp.location_sampling_method_after_conditioning    = 'sampling';
%     temp.internal_support_threshold = temp.total_support_threshold_2;
%     temp.total_support_threshold_1  = temp.total_support_threshold_2;
%     p_conditions_descriptions{end+1} = description;
%     if isempty( p_conditions ), p_conditions = temp; else p_conditions(end+1) = temp; end
%     
%     description = 'salience, normals, no mvn';
%     temp = p;
%     temp.location_method_before_conditioning            = 'salience_blurry';
%     temp.location_method_after_conditioning             = 'salience_blurry';
%     temp.box_method_before_conditioning                 = 'independent_normals_log_aa';
%     temp.box_method_after_conditioning                  = 'independent_normals_log_aa';
%     temp.location_sampling_method_before_conditioning   = 'sampling';
%     temp.location_sampling_method_after_conditioning    = 'sampling';
%     temp.internal_support_threshold = temp.total_support_threshold_2;
%     temp.total_support_threshold_1  = temp.total_support_threshold_2;
%     p_conditions_descriptions{end+1} = description;
%     if isempty( p_conditions ), p_conditions = temp; else p_conditions(end+1) = temp; end
%
%     description = 'uniform, normals, learned mvn';
%     temp = p;
%     temp.location_method_before_conditioning            = 'uniform';
%     temp.location_method_after_conditioning             = 'mvn_conditional';
%     temp.box_method_before_conditioning                 = 'independent_normals_log_aa';
%     temp.box_method_after_conditioning                  = 'conditional_mvn_log_aa';
%     temp.location_sampling_method_before_conditioning   = 'sampling';
%     temp.location_sampling_method_after_conditioning    = 'sampling';
%     p_conditions_descriptions{end+1} = description;
%     if isempty( p_conditions ), p_conditions = temp; else p_conditions(end+1) = temp; end
%
%     description = 'salience, uniform, no mvn';
%     temp = p;
%     temp.location_method_before_conditioning            = 'salience_blurry';
%     temp.location_method_after_conditioning             = 'salience_blurry';
%     temp.box_method_before_conditioning                 = 'independent_uniform_log_aa';
%     temp.box_method_after_conditioning                  = 'independent_uniform_log_aa';
%     temp.location_sampling_method_before_conditioning   = 'sampling';
%     temp.location_sampling_method_after_conditioning    = 'sampling';
%     p_conditions_descriptions{end+1} = description;
%     if isempty( p_conditions ), p_conditions = temp; else p_conditions(end+1) = temp; end
%    
%     description = 'uniform, normals, no mvn';
%     temp = p;
%     temp.location_method_before_conditioning            = 'uniform';
%     temp.location_method_after_conditioning             = 'uniform';
%     temp.box_method_before_conditioning                 = 'independent_normals_log_aa';
%     temp.box_method_after_conditioning                  = 'independent_normals_log_aa';
%     temp.location_sampling_method_before_conditioning   = 'sampling';
%     temp.location_sampling_method_after_conditioning    = 'sampling';
%     p_conditions_descriptions{end+1} = description;
%     if isempty( p_conditions ), p_conditions = temp; else p_conditions(end+1) = temp; end
%  
%     description = 'uniform, uniform, no mvn';
%     temp = p;
%     temp.location_method_before_conditioning            = 'uniform';
%     temp.location_method_after_conditioning             = 'uniform';
%     temp.box_method_before_conditioning                 = 'independent_uniform_log_aa';
%     temp.box_method_after_conditioning                  = 'independent_uniform_log_aa';
%     temp.location_sampling_method_before_conditioning   = 'sampling';
%     temp.location_sampling_method_after_conditioning    = 'sampling';
%     p_conditions_descriptions{end+1} = description;
%     if isempty( p_conditions ), p_conditions = temp; else p_conditions(end+1) = temp; end
  
    
   % validate the options before we start running with them
   if all( arrayfun( @situate_parameters_validate, p_conditions ) )
       display('situate parameters validation passed');
   end

%% generate training and testing sets
  
    testing_fname_blacklist = {}; 
    % testing_fname_blacklist should be used if there's some saved off model that we want to mess with. 
    % everything in the blacklist will be forced into the training set
    
    if exist('training_data_max','var') && ~isempty(training_data_max) && training_data_max > 0
        warning('situate using limited training data');
    end
    
    if use_training_testing_split_files
        
        % load the splits rather than generating new onces
        
        fnames_splits_path  = 'fnames_splits/'; % just search the local directory
        fnames_splits_train = dir([fnames_splits_path experiment_title '_fnames_split_*_train.txt']);
        fnames_splits_test  = dir([fnames_splits_path experiment_title '_fnames_split_*_test.txt']);
        fnames_splits_train = cellfun( @(x) [fnames_splits_path x], {fnames_splits_train.name}, 'UniformOutput', false );
        fnames_splits_test  = cellfun( @(x) [fnames_splits_path x], {fnames_splits_test.name},  'UniformOutput', false );
        assert( length(fnames_splits_train) == length(fnames_splits_test) );
        temp.fnames_lb_train = cellfun( @(x) importdata(x, '\n'), fnames_splits_train, 'UniformOutput', false );
        temp.fnames_lb_test  = cellfun( @(x) importdata(x, '\n'), fnames_splits_test,  'UniformOutput', false );
        data_split = [];
        for i = 1:length(temp.fnames_lb_train)
            data_split(i).fnames_lb_train = temp.fnames_lb_train{i};
            data_split(i).fnames_lb_test  = temp.fnames_lb_test{i};
            data_split(i).fnames_im_train = cellfun( @(x) [x(1:end-4) 'jpg'], temp.fnames_lb_train{1}, 'UniformOutput', false );
            data_split(i).fnames_im_test  = cellfun( @(x) [x(1:end-4) 'jpg'], temp.fnames_lb_test{1},  'UniformOutput', false );
        end
           
    else
        
    % generate new splits, and save the files to the local directory. 
    % note: this is not where they're loaded from. if youw ant to keep the
    % split, they need to be moved to the fnames_splits directory
        
        if isempty(data_path) || ~exist(data_path,'dir')
            data_path = uigetdir([],'Select path containing images and label files');
        end
        dir_data = dir(fullfile(data_path, '*.labl'));
        fnames_lb = {dir_data.name};

    % load all of the data from the data directory, divide into
    % training/testing splits, and save off the split
     
        % make sure all of the label files have an associated image file
        is_missing_image_file = false(1,length(fnames_lb));
        for fi = 1:length(fnames_lb)
            is_missing_image_file(fi) = ~exist( fullfile(data_path, [fnames_lb{fi}(1:end-5) '.jpg' ]),'file');
        end
        fnames_lb(is_missing_image_file) = [];
        fnames_im = cellfun( @(x) [x(1:end-5) '.jpg'], fnames_lb, 'UniformOutput', false );
        
    % see if there is an intersection between the testing blacklist and what we have

        intersect_inds = false(length(fnames_lb),1);
        for i = 1:length(fnames_lb)
            intersect_inds(i) = any( strcmp( fnames_im{i}, testing_fname_blacklist ) );
        end
        fnames_lb_available_for_testing = fnames_lb(~intersect_inds);
        fnames_im_available_for_testing = fnames_im(~intersect_inds);
        % shuffle
        rp = randperm( length(fnames_lb_available_for_testing) );
        fnames_lb_available_for_testing = fnames_lb_available_for_testing(rp);
        fnames_im_available_for_testing = fnames_im_available_for_testing(rp);
        
    % generate training/testing splits for cross validation
    
        n = length(fnames_lb_available_for_testing);
        step = floor( n / num_folds );
        cut_starts = (0:step:n-step)+1;
        cut_ends   = cut_starts + step - 1;
        
        if ~isempty(testing_data_max) && step > testing_data_max
            cut_ends = cut_starts + testing_data_max - 1;
            warning('situate_experiment:using subset of available data');
        end
            
        data_split = [];
        data_split.fnames_im_train = [];
        data_split.fnames_im_test  = [];
        data_split.fnames_lb_train = [];
        data_split.fnames_lb_test  = [];
        data_split = repmat(data_split,1,num_folds);
        for i = 1:num_folds
            data_split(i).fnames_lb_test  = fnames_lb_available_for_testing( cut_starts(i):cut_ends(i) );
            data_split(i).fnames_lb_train = setsub( fnames_lb, data_split(i).fnames_lb_test );
            data_split(i).fnames_im_test  = cellfun( @(x) [x(1:end-5) '.jpg'], data_split(i).fnames_lb_test,  'UniformOutput', false );
            data_split(i).fnames_im_train = cellfun( @(x) [x(1:end-5) '.jpg'], data_split(i).fnames_lb_train, 'UniformOutput', false );
            
            if exist('training_data_max','var') && ~isempty(training_data_max) && training_data_max > 0
                data_split(i).fnames_lb_train = data_split(i).fnames_lb_train(1:training_data_max);
                data_split(i).fnames_im_train = data_split(i).fnames_im_train(1:training_data_max);
            end
            
        end
        
        % save splits to files
        for i = 1:length(data_split)
            fname_train_out = [experiment_title '_fnames_split_' num2str(i,'%02d') '_train.txt'];
            fname_test_out  = [experiment_title '_fnames_split_' num2str(i,'%02d') '_test.txt' ];
            fid_train = fopen(fname_train_out,'w+');
            fid_test  = fopen(fname_test_out, 'w+');
            fprintf(fid_train,'%s\n',data_split(i).fnames_lb_train{:});
            fprintf(fid_test, '%s\n',data_split(i).fnames_lb_test{:} );
            fclose(fid_train);
            fclose(fid_test);
        end
           
    end    
     
    

%% run the main loop

    scout_record = []; 
        % this is just used when classification method is 'crop generator', 
        % which is to say, we want to keep images that are sent to the 
        % oracle using whatever settings we currently have. probably not 
        % the best way to do it, should probably toss it.
    
    %for split_ind = 1
    for fold_ind = 1:num_folds
        
        learned_stuff = [];
        
        % get current training and testing file names
        
            fnames_lb_train = cellfun( @(x) fullfile(data_path, x), data_split(fold_ind).fnames_lb_train, 'UniformOutput', false );
            fnames_lb_test  = cellfun( @(x) fullfile(data_path, x), data_split(fold_ind).fnames_lb_test,  'UniformOutput', false );
        
            [fnames_lb_train_pass, fnames_lb_train_fail, exceptions] = situate_validate_training_data( fnames_lb_train, p_conditions(1) );
            if ~isempty(fnames_lb_train_fail)
                warning('some training images were excluded');
                display(fnames_lb_train_fail);
                fnames_lb_train = fnames_lb_train_pass;
            end
        
            fnames_im_train = cellfun( @(x) fullfile(data_path, x), data_split(fold_ind).fnames_im_train, 'UniformOutput', false );
            fnames_im_test  = cellfun( @(x) fullfile(data_path, x), data_split(fold_ind).fnames_im_test,  'UniformOutput', false );
            
        % run situate on test images with each experimental setting
            workspaces_final           = cell(length(p_conditions),length(fnames_im_test));
            workspace_entry_event_logs = cell(length(p_conditions),length(fnames_im_test));

            for experiment_ind = 1:length(p_conditions)

                cur_parameters = p_conditions(experiment_ind);
            
                image_ind = 1;
                keep_going = true;
                while keep_going
                    
                    if use_gui
                        h = situate_parameters_adjust_gui(cur_parameters);
                        uiwait(h);
                        if exist('temp_situate_parameters_struct.mat','file')
                            % the saddest hack. there's some security layer that
                            % prevents information from the gui from being brought
                            % back into the calling script. I'm sure there's a way,
                            % but until then, it's dumping out a little struct file
                            % with the changed parameters.
                            cur_parameters = load('temp_situate_parameters_struct.mat');
                            delete('temp_situate_parameters_struct.mat');
                            % exited properly, so feel free to keep going
                        else
                            % the file wasn't there, so we didn't exit properly, so don't
                            % keep going
                            break;
                        end
                    end
                    
                    
                    % make sure we have all of the necessary models for the
                    % run that we're about to perform.
                    %
                    % either build or load
                    
                    % build whatever needs to be built based on the training data, 
                    %   (conditional distribution structures, classifiers, etc)
                    
                    % checking for existing models
                    %   this assumes that the saved model .mat
                    %   file has a field called fnames_lb_train.
                    %   it'll be compared against the current
                    %   fnames_lb_train. An exact match (ignoring path)
                    %   will lead to the model being loaded instead of 
                    %   built
                    
                        % conditional distribution models
                        if strncmp( 'mvn_conditional', cur_parameters.location_method_after_conditioning, length('mvn_conditional') ) ...
                        || strncmp( 'conditional_mvn', cur_parameters.box_method_after_conditioning,      length('conditional_mvn') )
                            learned_stuff.conditional_models_structure = situate_build_conditional_distribution_structure( fnames_lb_train, p );
                            % hack to make the current 4 object version work with 3 objects again
                            if length(cur_parameters.situation_objects) == 3
                                none_index_for_three_objects = 4;
                                learned_stuff.conditional_models_structure.models = learned_stuff.conditional_models_structure.models(:,:,:,none_index_for_three_objects);
                            end
                        end
                        
                        % box adjust models
                        if cur_parameters.use_box_adjust
                            if isfield(learned_stuff, 'box_adjust_models'),
                                % do nothing
                            elseif ~isempty(situate_check_for_existing_model( saved_model_path_box_adjust, fnames_lb_train ))
                                learned_stuff.box_adjust_models = load(situate_check_for_existing_model( saved_model_path_box_adjust, fnames_lb_train ));
                                display('loaded saved box_adjust_model');
                            else
                                box_adjust_models = box_adjust.build_box_adjust_models_mq( fnames_lb_train, p );
                                box_adjust_models.fnames_lb_train = fnames_lb_train;
                                box_adjust_models.p = p;
                                saved_model_fname = fullfile(saved_model_path_box_adjust, ['box_adjust_models_' datestr(now,'yyyy.mm.dd.HH.MM.SS') '.mat']);
                                save( saved_model_fname, '-struct', 'box_adjust_models' );
                                learned_stuff.box_adjust_models = box_adjust_models;
                            end
                        end
                        
                        % cnn models
                        if strcmp( 'CNN-SVM', cur_parameters.classification_method )
                            if isfield(learned_stuff, 'cnn_svm_models'), 
                                % do nothing
                            elseif ~isempty(situate_check_for_existing_model( saved_model_path_cnn_svm, fnames_lb_train ))
                                learned_stuff.cnn_svm_models = load(situate_check_for_existing_model( saved_model_path_cnn_svm, fnames_lb_train ));
                                display('loaded saved cnn_svm_model');
                            else
                                cnn_svm_models.models          = cnn.create_cnn_svm_models(fnames_lb_train, p);
                                cnn_svm_models.fnames_lb_train = fnames_lb_train;
                                cnn_svm_mdoels.p               = p;
                                saved_model_fname = fullfile(saved_model_path_cnn_svm, ['cnn_svm_models_' datestr(now,'yyyy.mm.dd.HH.MM.SS') '.mat']);
                                save( saved_model_fname, '-struct', 'cnn_svm_models' );
                                learned_stuff.cnn_svm_models = cnn_svm_models;
                            end
                        end
                        
                        % hog svm models
                        if strcmp( 'HOG-SVM', cur_parameters.classification_method )
                            if isfield(learned_stuff, 'hog_svm_models'), 
                                % do nothing
                            elseif ~isempty(situate_check_for_existing_model( saved_model_path_hog_svm, fnames_lb_train ))
                                learned_stuff.hog_svm_models = load(situate_check_for_existing_model( saved_model_path_hog_svm, fnames_lb_train ));
                                display('loaded saved hog_svm_model');
                            else
                                hog_svm_models = situate_build_hog_svm_models(fnames_lb_train, p);
                                hog_svm_models.fnames_lb_train = fnames_lb_train;
                                hog_svm_models.p = p;
                                saved_model_fname = fullfile(saved_model_path_hog_svm, ['hog_svm_models_' datestr(now,'yyyy.mm.dd.HH.MM.SS') '.mat']);
                                save( saved_model_fname, '-struct', 'hog_svm_models' );
                                learned_stuff.hog_svm_models = hog_svm_models;
                            end
                        end
                        
                        % fast-rcnn scores for testing images
                        if cur_parameters.rcnn_boxes
                            if exist('faster_rcnn_data_for_fold','var')
                                % do nothing
                            else
                                assert( isequal(situation,'dogwalking') );
                                faster_rcnn_data_raw = load('/Users/Max/Dropbox/situate_snapshot_current/saved_models_rcnn_scores/faster_rcnn_boxes.mat');
                                last = @(x) x(end);
                                fnames_im_test_no_path = cellfun( @(x) x( last(strfind(x,filesep()))+1 : end ), fnames_im_test, 'UniformOutput', false );
                                faster_rcnn_fnames_im  = cellfun( @(x) x( last(strfind(x,filesep()))+1 : end ), faster_rcnn_data_raw.im_names, 'UniformOutput', false );
                                inds_keep = ismember( faster_rcnn_fnames_im, fnames_im_test_no_path );    
                                faster_rcnn_data_for_fold = [];
                                faster_rcnn_data_for_fold.boxes_xywh = cellfun( @(x) x(:,1:4), faster_rcnn_data_raw.output(2,inds_keep)', 'UniformOutput', false);
                                faster_rcnn_data_for_fold.box_scores = cellfun( @(x) x(:,5),   faster_rcnn_data_raw.output(2,inds_keep)', 'UniformOutput', false);
                                faster_rcnn_data_for_fold.fnames_im  = faster_rcnn_fnames_im(inds_keep);
                            end
                            
                        end

                        
                        
                    % run on the current image
                    
                    cur_fname = fnames_im_test{image_ind};

                    % if using the precomputed rcnn boxes, grab the set for
                    % this image
                    if cur_parameters.rcnn_boxes
                        [~,linear_scaling_factor] = imresize_px( imread(cur_fname), p.image_redim_px );
                        cur_image_rcnn_ind = find(strcmp( faster_rcnn_data_for_fold.fnames_im, cur_fname(last(strfind(cur_fname,filesep()))+1:end) ) );
                        faster_rcnn_data = [];
                        faster_rcnn_data.boxes_xywh = linear_scaling_factor * double(faster_rcnn_data_for_fold.boxes_xywh{cur_image_rcnn_ind});
                        faster_rcnn_data.box_scores = faster_rcnn_data_for_fold.box_scores{cur_image_rcnn_ind};
                        learned_stuff.faster_rcnn_data = faster_rcnn_data;
                    end
                    
                    tic;
                    [workspaces_final{experiment_ind,image_ind},d,~,~,~,workspace_entry_event_logs{experiment_ind,image_ind},return_status_string,scout_record] = situate_sketch(cur_fname, cur_parameters, learned_stuff);
                    num_iterations_run = sum(cellfun(@(x) ~isempty(x),{scout_record.interest}));
                    progress_string = [p_conditions_descriptions{experiment_ind} ', ' num2str(num_iterations_run), ' steps, ' num2str(toc) 's'];
                    progress(image_ind,length(fnames_im_test),progress_string);
                    
                    if strcmp(cur_parameters.classification_method,'crop_generator')
                        scout_records_temp = scout_record;
                        scout_records_temp.im_fname = cur_fname;
                        if isempty(scout_records), scout_records = scout_records_temp; else scout_records(end+1) = scout_records_temp; end
                    end

                    % deal with GUI inputs
                    if use_gui

                        switch return_status_string
                            case 'restart'
                                % cur_image_ind = cur_image_ind;
                                % keep_going = true;
                                % no op
                            case 'next_image'
                                image_ind = image_ind + 1;
                                % keep_going = true;
                            case 'stop'
                                keep_going = false;
                            otherwise
                                keep_going = false;
                                % because we probably killed it with a window close
                        end

                        if image_ind > testing_data_max
                            keep_going = false;
                            msgbox('out of testing images');
                        end

                        if ~keep_going
                            break
                        end

                    else % we're not using the GUI, so move on to the next image
                        image_ind = image_ind + 1;
                        if image_ind > length(fnames_im_test), keep_going = false; end
                    end

                end

                
                if use_gui
                    % bail after the first experimental setup if we're using the GUI
                    break;
                end

            end

        if use_gui
            % bail after the first fold if we're using the GUI
            break; 
        else
            save_fname = [experiment_title '_split_' num2str(fold_ind,'%02d') '_' datestr(now,'yyyy.mm.dd.HH.MM.SS') '.mat'];
            save(save_fname, ...
                'p_conditions', ...
                'p_conditions_descriptions', ...
                'workspaces_final', ...
                'workspace_entry_event_logs', ...
                'fnames_im_train', 'fnames_im_test',...
                'fnames_lb_train', 'fnames_lb_test');
            display(['saved to ' pwd '/' save_fname]);
        end
        
    end
        
    
     
















    