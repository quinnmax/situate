



warning('off','situate:newmethodwarning')

    rng('shuffle')
    
    num_splits = 2;
    testing_data_max = 500;
    use_training_testing_split_files = false;
    
    %testing_data_max = 5; % this will force it to use .5*length(fnames_lb)


%% set up general situate parameteres

    p = situate_parameters_initialize();
    
    % pipeline
        p.use_direct_scout_to_workspace_pipe = true;          
        p.refresh_agent_pool_after_workspace_change = true;   
    
    % object priority
        % p.object_type_priority_before_example_is_found = 1;  
        % p.object_type_priority_after_example_is_found  = 0;  
    
    % search, inhibition, and distribution padding
        % p.inhibition_method = 'blackman';                     
        % p.dist_xy_padding_value = .05;    
        % p.inhibition_intensity = .5;      
        p.num_iterations = 10;         
    
    % check-in and tweaking
        % p.use_distribution_tweaking = false;                  
        % p.internal_support_threshold = .25; % scout -> reviewer threshold
        % p.total_support_threshold_1  = .25; % workspace provisional check-in threshold (search continues)
        % p.total_support_threshold_2  = .5;  % sufficient detection threshold (ie, good enough to end search for that oject)
    
    % set up visualization parameters
        p.show_visualization_on_iteration           = false;
        p.show_visualization_on_iteration_mod       = 1; % moot
        p.show_visualization_on_workspace_change    = false;
        p.show_visualization_on_end                 = false;
        p.start_paused                              = false;
   
        
    
%% define experimental settings

    p_conditions = [];
    p_conditions_descriptions = {};
    
   % crop generator
    
    description = 'sampling, location:uniform, boxes:uniform, conditioning:off';
    temp = p;
    
    temp.classification_method                          = 'crop_generator';
    
    temp.box_method_before_conditioning                 = 'independent_normals_log_aa';
    temp.box_method_after_conditioning                  = 'independent_normals_log_aa';
    temp.location_sampling_method_before_conditioning   = 'sampling';
    temp.location_sampling_method_after_conditioning    = 'sampling';
    temp.location_method_before_conditioning            = 'uniform';
    temp.location_method_after_conditioning             = 'uniform';
    
    p_conditions_descriptions{end+1} = description;
    if isempty( p_conditions ), p_conditions = temp; else p_conditions(end+1) = temp; end
    
    
 


%% Load necessary classification models
% Make a black-list of images that were used to train them.
% 
% Those images will still be used to train the conditional model for object
% locations, but won't be used in any of the testing.

    testing_fname_blacklist = {};

    if any( strcmp( 'HOG-SVM', {p_conditions.classification_method} ) )

        hog_svm_model_fname = 'hog_svm_model_saved.mat';
        if exist(hog_svm_model_fname,'file')
            load(hog_svm_model_fname,'hog_svm_model');
            % contains:
            %   hog_svm_model
            fnames_hog_svm_training = ...
                [ hog_svm_model(1).training_crop_source_list ...
                  hog_svm_model(2).training_crop_source_list ...
                  hog_svm_model(3).training_crop_source_list ];

            for i = 1:length(fnames_hog_svm_training)
                temp = split(fnames_hog_svm_training{i},'/');
                fnames_hog_svm_training{i} = temp{end};
            end
        else
            fnames_hog_svm_training = {};
        end
        
        testing_fname_blacklist = [testing_fname_blacklist fnames_hog_svm_training];
        
    end

    

%% generate training and testing sets

    
    data_path = situate_images_default_directories();
    if ~exist(data_path,'dir')
        data_path = uigetdir([],'Select path containing images and label files');
        data_path = [data_path '/'];
    end
    dir_data = dir([ data_path '*.labl' ]);
    fnames_lb = {dir_data.name};

    
    if use_training_testing_split_files
    % load testing/training splits from files
        
        fnames_splits_path = ''; % just search the local directory
        
        fnames_splits_train = dir([fnames_splits_path 'fnames_split_*_train.txt']);
        fnames_splits_test  = dir([fnames_splits_path 'fnames_split_*_test.txt']);
        if length(fnames_splits_train) ~= length(fnames_splits_test)
            error('situate_experiment:loading_splits','not the same number of training and testing splits');
        end
        split = [];
        for i = 1:length(fnames_splits_train)
            cur_fname_train = [fnames_splits_path fnames_splits_train(i).name];
            cur_fname_test  = [fnames_splits_path fnames_splits_test(i).name];
            
            split(i).fnames_lb_train = importdata(cur_fname_train, '\n');
            split(i).fnames_lb_test  = importdata(cur_fname_test, '\n');
            
            split(i).fnames_im_train = cellfun( @(x) [x(1:end-5) '.jpg'], split(i).fnames_lb_train,  'UniformOutput', false );
            split(i).fnames_im_test  = cellfun( @(x) [x(1:end-5) '.jpg'], split(i).fnames_lb_test,   'UniformOutput', false );
        end
        

    else
    % load all of the data from the data directory, divide into
    % training/testing splits, and save off the split
     
        % make sure all of the label files have an associated image file
        is_missing_image_file = false(1,length(fnames_lb));
        for fi = 1:length(fnames_lb)
            is_missing_image_file(fi) = ~exist( [data_path fnames_lb{fi}(1:end-5) '.jpg' ],'file');
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

    % generate training/testing splits for cross validation
    
        n = length(fnames_lb_available_for_testing);
        step = floor( n / num_splits );
        cut_starts = (0:step:n-step)+1;
        cut_ends   = cut_starts + step - 1;
        
        % if we don't have a testing_data_max set, 
        % use no more than half of the total data
        if ~exist('testing_data_max','var') || isempty(testing_data_max) || testing_data_max == 0
            testing_data_max = .5*length(fnames_lb);
            warning('situate_experiment:using default testing_data_max, min(.5 total, split size)');
        end
        
        if step > testing_data_max
            cut_ends = cut_starts + testing_data_max - 1;
            warning('situate_experiment:using subset of available data');
        end
            
        split = [];
        split.fnames_im_train = [];
        split.fnames_im_test  = [];
        split.fnames_lb_train = [];
        split.fnames_lb_test  = [];
        split = repmat(split,1,num_splits);
        for i = 1:num_splits
            split(i).fnames_lb_test  = fnames_lb_available_for_testing( cut_starts(i):cut_ends(i) );
            split(i).fnames_lb_train = setsub( fnames_lb, split(i).fnames_lb_test );
            split(i).fnames_im_test  = cellfun( @(x) [x(1:end-5) '.jpg'], split(i).fnames_lb_test,  'UniformOutput', false );
            split(i).fnames_im_train = cellfun( @(x) [x(1:end-5) '.jpg'], split(i).fnames_lb_train, 'UniformOutput', false );
        end
        
        % save splits to files
        for i = 1:length(split)
            fname_train_out = ['fnames_split_' num2str(i,'%02d') '_train.txt'];
            fname_test_out  = ['fnames_split_' num2str(i,'%02d') '_test.txt' ];
            fid_train = fopen(fname_train_out,'w+');
            fid_test  = fopen(fname_test_out, 'w+');
            fprintf(fid_train,'%s\n',split(i).fnames_lb_train{:});
            fprintf(fid_test, '%s\n',split(i).fnames_lb_test{:} );
            fclose(fid_train);
            fclose(fid_test);
        end
           
    end    
     
    
    
%% run through the experiment for each split

    scout_records = [];

    for split_ind = 1:num_splits
        
        fnames_im_train = cellfun( @(x) [data_path x], split(split_ind).fnames_im_train, 'UniformOutput', false );
        fnames_im_test  = cellfun( @(x) [data_path x], split(split_ind).fnames_im_test,  'UniformOutput', false );
        fnames_lb_train = cellfun( @(x) [data_path x], split(split_ind).fnames_lb_train, 'UniformOutput', false );
        fnames_lb_test  = cellfun( @(x) [data_path x], split(split_ind).fnames_lb_test,  'UniformOutput', false );
        
        % build whatever need to be built based on the training data, such as conditional distribution structures and classifiers
        conditional_models_structure = situate_build_conditional_distribution_structure( fnames_lb_train );
        learned_stuff.conditional_models_structure = conditional_models_structure;
        warning('situate:newmethodwarning','new method code goes here');

        % run situate on test images with each experimental setting
        workspaces_final = cell(length(p_conditions),length(fnames_im_test));
        workspace_entry_event_logs = cell(length(p_conditions),length(fnames_im_test));

        for experiment_ind = 1:length(p_conditions)

            % select a set of parameters, defining an experiment
            cur_p = p_conditions(experiment_ind);

            for imi = 1:length(fnames_im_test)

                tic
                cur_fname = fnames_im_test{imi};
                [workspaces_final{experiment_ind,imi},d,~,~,~,workspace_entry_event_logs{experiment_ind,imi},~,scout_record] = situate_sketch(cur_fname, cur_p, learned_stuff);
                progress(imi,length(fnames_im_test),[p_conditions_descriptions{experiment_ind} ', ' num2str(sum(~eq(scout_record.box_r0rfc0cf(:,1),0))), ' steps, ' num2str(toc) 's']);
            
                if strcmp(cur_p.classification_method,'crop_generator')
                    scout_records_temp = scout_record;
                    scout_records_temp.im_fname = cur_fname;
                    if isempty(scout_records), scout_records = scout_records_temp; else scout_records(end+1) = scout_records_temp; end
                end
            
            end
            
        end
        
        finish_time_str = datestr(now,'yyyy.mm.dd.HH.MM.SS');
        
        save_fname = ['situate_experiment_results_' 'split_' num2str(split_ind,'%02d') '_' finish_time_str '.mat'];
        save(save_fname, ...
            'p_conditions', ...
            'p_conditions_descriptions', ...
            'workspaces_final', ...
            'workspace_entry_event_logs', ...
            'fnames_im_train', 'fnames_im_test',...
            'fnames_lb_train', 'fnames_lb_test');

        display(['saved to ' pwd '/' save_fname]);
        
       
        
    end

    
    
    if ~isempty(scout_records)
        scout_record_fname = ['scout_records_' finish_time_str '.mat'];
        save(scout_record_fname,'scout_records');
        display(scout_record_fname);
    end
    























