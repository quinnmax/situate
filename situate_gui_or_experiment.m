
    
function [] = situate_gui_or_experiment()

% basic setup

    use_gui = false; 
    % use_gui limits the testing data and the limits the run to one
    % experimental condition and one fold (as specified in the experimental
    % setup, you can still modify settings in the settings GUI)

    situation = 'dogwalking';
    % situation = 'dogwalking_no_leash';
    % situation = 'handshaking';
    % situation = 'pingpong';
    % see situate_situation_definitions to add more
   
    experiment_title = 'experiment_name';
    
    % if you want to use pre-existing fold files, 
    % specify a results directory that already exists and has the fold files already present
    use_existing_training_testing_split_files = false;
    
    % results_directory = 'whatever you want';
    results_directory = fullfile('/Users/',char(java.lang.System.getProperty('user.name')),'/Desktop/', [experiment_title '_' datestr(now,'yyyy.mm.dd.HH.MM.SS')]);
    if ~exist(results_directory,'dir'), mkdir(results_directory); display(['made directory ' results_directory]); end

    num_folds = 1;
    testing_data_max  = 1;      % empty will use as much as possible given the folds.
    training_data_max = 10;     % empty will use as much as possible given the folds. 
                                % if you use less than 50, the multivariate normals will probably bust.
                             
    run_analysis_after_completion = false;

    rng(1);
    %rng('shuffle');

% make sure the path is set up properly
    situate_gui_or_experiment_path = fileparts(which('situate_gui_or_experiment'));
    addpath(fullfile(situate_gui_or_experiment_path));
    addpath(genpath(fullfile(situate_gui_or_experiment_path, 'tools')));
    
    
%% shared situate parameteres 
%   these are the base parameters that can be modified for different
%   experimental settings. generally the things that will be the same for
%   each of the conditions specified later
    
    p = situate_parameters_initialize();
    
    p.rcnn_boxes = false;
    
    % classifier
        p.classification_method  = 'IOU-oracle';
        % p.classification_method  = 'CNN-SVM'; % uses Rory's cnn code
        % p.classification_method  = 'HOG-SVM';
        
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
        % p.total_support_threshold_1  = .25; % workspace provisional check-in threshold (search continues)
        % p.total_support_threshold_2  = .5;  % sufficient detection threshold (ie, good enough to end search for that oject)

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
    
    
    
%% situation definitions 
%
% edit: this should be selectable from the gui form

situations_struct = situate_situation_definitions();

p.situation_objects                 = situations_struct.(situation).situation_objects;
p.situation_objects_possible_labels = situations_struct.(situation).situation_objects_possible_labels;

existing_path_ind = find(cellfun( @(x) exist(x,'dir'), situations_struct.(situation).possible_paths ));
if ~isempty(existing_path_ind) 
    situate_data_path = situations_struct.(situation).possible_paths{existing_path_ind};
else
    situate_data_path = [];
    while ~exist('situate_data_path','dir') || isempty(situate_data_path)
        h = msgbox( ['Select directory containing images of ' situation] );
        uiwait(h);
        situate_data_path = uigetdir(pwd); 
    end
end



%% experimental situate parameters 
%
% these are modifications to the shared situation parameters defined above.
% anything not specified will use those settings.
%
% if using the gui, 
% the first setting will be used to populate the gui settings popup, 
% the rest will be ignored

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
 
    description = 'uniform, uniform, no mvn';
    temp = p;
    temp.location_method_before_conditioning            = 'uniform';
    temp.location_method_after_conditioning             = 'uniform';
    temp.box_method_before_conditioning                 = 'independent_uniform_log_aa';
    temp.box_method_after_conditioning                  = 'independent_uniform_log_aa';
    temp.location_sampling_method_before_conditioning   = 'sampling';
    temp.location_sampling_method_after_conditioning    = 'sampling';
    p_conditions_descriptions{end+1} = description;
    if isempty( p_conditions ), p_conditions = temp; else p_conditions(end+1) = temp; end
  
    
   % validate the options before we start running with them
   %    this just checks that methods_before and method_after type stuff is
   %    set to something present in the method_options arrays. just to
   %    catch typos and stuff here.
   assert( all( arrayfun( @situate_parameters_validate, p_conditions ) ) );
       
   
   
%% set training and testing sets, load any existing models
  
    fname_blacklist = {}; 
    % fname_blacklist should be used if there's some saved off model that 
    % we want to mess with. 
    % Everything in the fname_blacklist will be excluded from both the
    % training and testing images that are used for learning the
    % conditional model stuff
    
    if use_existing_training_testing_split_files
        
        % Load the splits rather than generating new ones
        % edit: currently looks for the existing experiment name in the
        % title of the split file. not sure that that should be necessary.
        % something to think about and adjust in the future
        
        fnames_splits_train = dir(fullfile(results_directory ,[experiment_title '_fnames_split_*_train.txt']));
        fnames_splits_test  = dir(fullfile(results_directory, [experiment_title '_fnames_split_*_test.txt' ]));
        fnames_splits_train = cellfun( @(x) fullfile(results_directory, x), {fnames_splits_train.name}, 'UniformOutput', false );
        fnames_splits_test  = cellfun( @(x) fullfile(results_directory, x), {fnames_splits_test.name},  'UniformOutput', false );
        assert( length(fnames_splits_train) > 0 );
        assert( length(fnames_splits_train) == length(fnames_splits_test) );
        temp = [];
        temp.fnames_lb_train = cellfun( @(x) importdata(x, '\n'), fnames_splits_train, 'UniformOutput', false );
        temp.fnames_lb_test  = cellfun( @(x) importdata(x, '\n'), fnames_splits_test,  'UniformOutput', false );
        data_folds = [];
        for i = 1:length(temp.fnames_lb_train)
            data_folds(i).fnames_lb_train = temp.fnames_lb_train{i};
            data_folds(i).fnames_lb_test  = temp.fnames_lb_test{i};
            data_folds(i).fnames_im_train = cellfun( @(x) [x(1:end-4) 'jpg'], temp.fnames_lb_train{1}, 'UniformOutput', false );
            data_folds(i).fnames_im_test  = cellfun( @(x) [x(1:end-4) 'jpg'], temp.fnames_lb_test{1},  'UniformOutput', false );
        end
           
    else % generate splits based on situate_data_path, training_data_max, testing_data_max
        
        % generate new splits, and save the files to the split-file directory.
        
            % get the label files
            dir_data = dir(fullfile(situate_data_path, '*.labl'));
            fnames_lb = {dir_data.name};
            % get the associated image files
            is_missing_image_file = false(1,length(fnames_lb));
            for fi = 1:length(fnames_lb)
                is_missing_image_file(fi) = ~exist( fullfile(situate_data_path, [fnames_lb{fi}(1:end-5) '.jpg' ]),'file');
            end
            fnames_lb(is_missing_image_file) = [];
            fnames_im = cellfun( @(x) [x(1:end-5) '.jpg'], fnames_lb, 'UniformOutput', false );
            % remove anything that's on the blacklist
            [~,inds_remove_lb] = intersect(fnames_lb,fname_blacklist);
            [~,inds_remove_im] = intersect(fnames_im,fname_blacklist);
            fnames_lb([inds_remove_lb inds_remove_im]) = [];
            fnames_im([inds_remove_lb inds_remove_im]) = [];
            % shuffle
            rp = randperm( length(fnames_lb) );
            fnames_lb = fnames_lb(rp);
            fnames_im = fnames_im(rp);

        % generate training/testing splits for cross validation

            n = length(fnames_lb);
            step = floor( n / num_folds );
            fold_inds_start = (0:step:n-step)+1;
            fold_inds_end   = fold_inds_start + step - 1;
            if ~isempty(testing_data_max) && step > testing_data_max
                fold_inds_end = fold_inds_start + testing_data_max - 1;
                warning('situate_experiment:using subset of available data');
            end

            data_folds = [];
            data_folds.fnames_im_train = [];
            data_folds.fnames_im_test  = [];
            data_folds.fnames_lb_train = [];
            data_folds.fnames_lb_test  = [];
            data_folds = repmat(data_folds,1,num_folds);
            for i = 1:num_folds
                data_folds(i).fnames_lb_test  = fnames_lb( fold_inds_start(i):fold_inds_end(i) );
                data_folds(i).fnames_lb_train = setdiff( fnames_lb, data_folds(i).fnames_lb_test );
                data_folds(i).fnames_im_test  = cellfun( @(x) [x(1:end-5) '.jpg'], data_folds(i).fnames_lb_test,  'UniformOutput', false );
                data_folds(i).fnames_im_train = cellfun( @(x) [x(1:end-5) '.jpg'], data_folds(i).fnames_lb_train, 'UniformOutput', false );

                if exist('training_data_max','var') && ~isempty(training_data_max) && training_data_max > 0
                    warning('situate is using limited training data');
                    data_folds(i).fnames_lb_train = data_folds(i).fnames_lb_train(1:training_data_max);
                    data_folds(i).fnames_im_train = data_folds(i).fnames_im_train(1:training_data_max);
                end

            end

            % save splits to files
            if ~isdir(results_directory), mkdir(results_directory); end
            for i = 1:length(data_folds)
                fname_train_out = fullfile(results_directory, [experiment_title '_fnames_split_' num2str(i,'%02d') '_train.txt']);
                fid_train = fopen(fname_train_out,'w+');
                fprintf(fid_train,'%s\n',data_folds(i).fnames_lb_train{:});
                fclose(fid_train);
                
                fname_test_out  = fullfile(results_directory, [experiment_title '_fnames_split_' num2str(i,'%02d') '_test.txt' ]);
                fid_test  = fopen(fname_test_out, 'w+');
                fprintf(fid_test, '%s\n',data_folds(i).fnames_lb_test{:} );
                fclose(fid_test);
            end
           
    end    

    
    
%% run the main loop 


    for fold_ind = 1:num_folds
        
        learned_stuff = []; % contains everything we gather from training data, so is reset at the start of each fold
        
        % get current training and testing file names
        
            fnames_lb_test  = cellfun( @(x) fullfile(situate_data_path, x), data_folds(fold_ind).fnames_lb_test,  'UniformOutput', false );
            fnames_im_test  = cellfun( @(x) fullfile(situate_data_path, x), data_folds(fold_ind).fnames_im_test,  'UniformOutput', false );
            
            fnames_lb_train = cellfun( @(x) fullfile(situate_data_path, x), data_folds(fold_ind).fnames_lb_train, 'UniformOutput', false );
            fnames_im_train = cellfun( @(x) fullfile(situate_data_path, x), data_folds(fold_ind).fnames_im_train, 'UniformOutput', false );
            [fnames_lb_train_pass, ~, ~, failed_inds] = situate_validate_training_data( fnames_lb_train, p_conditions(1) );
            fnames_lb_train(failed_inds) = [];
            fnames_im_train(failed_inds) = [];
            
        % run through experimental settings
        
            workspaces_final           = cell(length(p_conditions),length(fnames_im_test));
            workspace_entry_event_logs = cell(length(p_conditions),length(fnames_im_test));

            for experiment_ind = 1:length(p_conditions)

                cur_experiment_parameters = p_conditions(experiment_ind);
            
                cur_image_ind  = 1;
                keep_going = true;
                while keep_going
                    
                    if use_gui
                        h = situate_parameters_adjust_gui(cur_experiment_parameters);
                        uiwait(h);
                        if exist('temp_situate_parameters_struct.mat','file')
                            % edit: the saddest hack. there's some security layer that
                            % prevents information from the gui from being brought
                            % back into the calling script. I'm sure there's a way to
                            % do this properly, but until then, it's dumping out a 
                            % little struct file with the changed parameters.
                            cur_experiment_parameters = load('temp_situate_parameters_struct.mat');
                            delete('temp_situate_parameters_struct.mat');
                            % exited properly, so feel free to keep going
                        else
                            % the file wasn't there, so we didn't exit properly, so don't
                            % keep going at all.
                            break;
                        end
                    end
                    
                    model_directories_struct = get_directories_for_necessary_models( cur_experiment_parameters );
                    
                    % build or load models for whatever is needed in the
                    % current condition ( classifiers, box adjust models,
                    % conditional distributions ) using the current
                    % training data
                    %
                    % existing models will be used if they contain a field
                    % fnames_lb_train, and that list perfectly matches the
                    % current training list.
                    
                        % conditional distribution models
                        if strncmp( 'mvn_conditional', cur_experiment_parameters.location_method_after_conditioning, length('mvn_conditional') ) ...
                        || strncmp( 'conditional_mvn', cur_experiment_parameters.box_method_after_conditioning,      length('conditional_mvn') )
                            learned_stuff.conditional_models_structure = situate_build_conditional_distribution_structure( fnames_lb_train, p );
                            % hack to make the current 4 object version work with 3 objects again
                            if length(cur_experiment_parameters.situation_objects) == 3
                                none_index_for_three_objects = 4;
                                learned_stuff.conditional_models_structure.models = learned_stuff.conditional_models_structure.models(:,:,:,none_index_for_three_objects);
                            end
                        end
                        
                        % box adjust models
                        if cur_experiment_parameters.use_box_adjust
                            if isfield(learned_stuff, 'box_adjust_models'),
                                % do nothing, it's already been dtrained with this data set
                            elseif ~isempty(situate_check_for_existing_model( model_directories_struct.box_adjust, fnames_lb_train ))
                                learned_stuff.box_adjust_models = load(situate_check_for_existing_model( model_directories_struct.box_adjust, fnames_lb_train ));
                                display('loaded saved box_adjust_model');
                            else
                                box_adjust_models = box_adjust.build_box_adjust_models_mq( fnames_lb_train, p );
                                box_adjust_models.fnames_lb_train = fnames_lb_train;
                                saved_model_fname = fullfile(model_directories_struct.box_adjust, ['box_adjust_models_' datestr(now,'yyyy.mm.dd.HH.MM.SS') '.mat']);
                                save( saved_model_fname, '-struct', 'box_adjust_models' );
                                learned_stuff.box_adjust_models = box_adjust_models;
                            end
                        end
                        
                        % cnn models
                        if strcmp( 'CNN-SVM', cur_experiment_parameters.classification_method )
                            if isfield(learned_stuff, 'cnn_svm_models'), 
                                % do nothing, it's already been dtrained with this data set
                            elseif ~isempty(situate_check_for_existing_model( model_directories_struct.cnn_svm, fnames_lb_train ))
                                learned_stuff.cnn_svm_models = load(situate_check_for_existing_model( model_directories_struct.cnn_svm, fnames_lb_train ));
                                display('loaded saved cnn_svm_model');
                            else
                                cnn_svm_models.models          = cnn.create_cnn_svm_models(fnames_lb_train, p);
                                cnn_svm_models.fnames_lb_train = fnames_lb_train;
                                saved_model_fname = fullfile(model_directories_struct.cnn_svm, ['cnn_svm_models_' datestr(now,'yyyy.mm.dd.HH.MM.SS') '.mat']);
                                save( saved_model_fname, '-struct', 'cnn_svm_models' );
                                learned_stuff.cnn_svm_models = cnn_svm_models;
                            end
                        end
                        
                        % hog svm models
                        if strcmp( 'HOG-SVM', cur_experiment_parameters.classification_method )
                            if isfield(learned_stuff, 'hog_svm_models'), 
                                % do nothing, it's already been dtrained with this data set
                            elseif ~isempty(situate_check_for_existing_model( model_directories_struct.hog_svm, fnames_lb_train ))
                                learned_stuff.hog_svm_models = load(situate_check_for_existing_model( model_directories_struct.hog_svm, fnames_lb_train ));
                                display('loaded saved hog_svm_model');
                            else
                                hog_svm_models = hog_svm.hog_svm_train(fnames_lb_train, p);
                                hog_svm_models.fnames_lb_train = fnames_lb_train;
                                saved_model_fname = fullfile(model_directories_struct.hog_svm, ['hog_svm_models_' datestr(now,'yyyy.mm.dd.HH.MM.SS') '.mat']);
                                save( saved_model_fname, '-struct', 'hog_svm_models' );
                                learned_stuff.hog_svm_models = hog_svm_models;
                            end
                        end
                        
                        % fast-rcnn scores for testing images
                        if cur_experiment_parameters.rcnn_boxes
                            if exist('faster_rcnn_data_for_fold','var')
                                % do nothing, it's already been dtrained with this data set
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
                    cur_fname = fnames_im_test{cur_image_ind};

                        % if using the precomputed rcnn boxes, grab the set for
                        % this image
                        if cur_experiment_parameters.rcnn_boxes
                            [~,linear_scaling_factor] = imresize_px( imread(cur_fname), p.image_redim_px );
                            cur_image_rcnn_ind = find(strcmp( faster_rcnn_data_for_fold.fnames_im, cur_fname(last(strfind(cur_fname,filesep()))+1:end) ) );
                            faster_rcnn_data = [];
                            faster_rcnn_data.boxes_xywh = linear_scaling_factor * double(faster_rcnn_data_for_fold.boxes_xywh{cur_image_rcnn_ind});
                            faster_rcnn_data.box_scores = faster_rcnn_data_for_fold.box_scores{cur_image_rcnn_ind};
                            learned_stuff.faster_rcnn_data = faster_rcnn_data;
                        end
                    
                    tic;
                    [workspaces_final{experiment_ind,cur_image_ind},d,~,run_data,visualizer_status_string] = situate_sketch(cur_fname, cur_experiment_parameters, learned_stuff);
                    
                    if isfield(run_data,'workspace_entry_events');
                        workspace_entry_event_logs{experiment_ind,cur_image_ind} = run_data.workspace_entry_events;
                    else
                        workspace_entry_event_logs = 'GUI didn''t produce workspace log';
                    end
                    num_iterations_run = sum(cellfun(@(x) ~isempty(x),{run_data.scout_record.interest}));
                    progress_string = [p_conditions_descriptions{experiment_ind} ', ' num2str(num_iterations_run), ' steps, ' num2str(toc) 's'];
                    progress(cur_image_ind,length(fnames_im_test),progress_string);
                   
                    % deal with GUI response
                    if use_gui

                        switch visualizer_status_string
                            case 'restart'
                                % cur_image_ind = cur_image_ind;
                                % keep_going = true;
                                % no op
                            case 'next_image'
                                cur_image_ind = cur_image_ind + 1;
                                % keep_going = true;
                            case 'stop'
                                keep_going = false;
                            otherwise
                                keep_going = false;
                                % because we probably killed it with a window close
                        end

                        if cur_image_ind > testing_data_max
                            keep_going = false;
                            msgbox('out of testing images');
                        end

                        if ~keep_going
                            break
                        end

                    else % we're not using the GUI, so move on to the next image
                        cur_image_ind = cur_image_ind + 1;
                        if cur_image_ind > length(fnames_im_test), keep_going = false; end
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
            save_fname = fullfile(results_directory, [experiment_title '_split_' num2str(fold_ind,'%02d') '_' datestr(now,'yyyy.mm.dd.HH.MM.SS') '.mat']);
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
    
    
    
    if run_analysis_after_completion
        situate_experiment_analysis( results_directory );
    end

end

function model_directories_struct = get_directories_for_necessary_models( p_conditions )

    model_directories_struct = [];

    if any(strcmp([ p_conditions.classification_method ],'CNN-SVM'))
        possible_paths_cnn_svm_models = { ...
            '/Users/Max/Documents/MATLAB/data/situate_saved_models/cnn_svm/', ...
            'saved_models_cnn_svm/', ...
            '+cnn/'};
        existing_model_path_ind = find(cellfun(@(x) exist(x,'dir'),possible_paths_cnn_svm_models), 1, 'first' );
        model_directories_struct.cnn_svm = possible_paths_cnn_svm_models{ existing_model_path_ind };
    end

    if any([ p_conditions.use_box_adjust ])
        possible_paths_box_adjust_models = {...
            '/stash/mm-group/evan/saved/models/box_adjust' ...
            '/Users/Max/Documents/MATLAB/data/situate_saved_models/box_adjust/', ...
            'saved_models_box_adjust/', ...
            '+box_adjust/'};
        existing_model_path_ind = find(cellfun(@(x) exist(x,'dir'),possible_paths_cnn_svm_models), 1, 'first' );
        model_directories_struct.box_adjust = possible_paths_cnn_svm_models{ existing_model_path_ind };
    end

    if any(strcmp([ p_conditions.classification_method ],'HOG-SVM'))
        possible_paths_hog_svm_models = {...
            '/Users/Max/Documents/MATLAB/data/situate_saved_models/hog_svm/', ...
            'saved_models_hog_svm/', ...
            '+hog_svm/'};
        existing_model_path_ind = find(cellfun(@(x) exist(x,'dir'),possible_paths_cnn_svm_models), 1, 'first' );
        model_directories_struct.hog_svm = possible_paths_cnn_svm_models{ existing_model_path_ind };
    end
    
end












