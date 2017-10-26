
    
function [] = experiment_helper_par(experiment_settings, parameterization_conditions, split_arg)
% experiment_helper_par(experiment_settings, p_conditions, split_arg)


  
%% training and testing sets
  
    generate_new_splits = false;

    % process the split arg
        if exist('split_arg','var') ...
        && ~isempty(split_arg)
    
            if isnumeric(split_arg)
                % we'll interpret it as a seed value
                rng(split_arg);
                generate_new_splits = true;
            elseif ischar(split_arg) && isdir(split_arg)
                % then it's a directory, we'll look for files that give file names to use as the splits
                split_file_directory = split_arg;
                data_folds = situate.load_data_splits_from_directory( split_file_directory );
            else
                % don't rightly know
                error('don''t know what to do with that split_arg');
            end
            
        else % split arg is empty, so try using the directories
            if isequal(experiment_settings.data_path_train,experiment_settings.data_path_test)
                % same folder, so generate splits of it
                rng(now);
                generate_new_splits = true;
            else
                % not the same folder, so use everything from training folder and test folder
                data_folds = [];
                
                temp = dir( fullfile(experiment_settings.data_path_train,'*.labl') );
                data_folds.fnames_lb_train = {temp.name};
                data_folds.fnames_im_train = cellfun( @(x) [x(1:end-4) 'jpg'], data_folds.fnames_lb_train, 'Uniformoutput', false );
                
                temp = dir( fullfile(experiment_settings.data_path_test,'*.jpg') );
                data_folds.fnames_im_test = {temp.name};
                data_folds.fnames_lb_test = cellfun( @(x) [x(1:end-3) 'labl'], data_folds.fnames_im_test, 'Uniformoutput', false );
                data_folds.fnames_lb_test( cellfun( @(x) ~exist(x,'file'), data_folds.fnames_lb_test ) ) = {''};
            end
        end
       
       
    % make sure the split fnames and the specified directories led to actual images
    % if not, replace training images with those in the training directory
    % if not, replace testing  images with those in the testing  directory
    
    if exist('data_folds','var')
    
        needed_to_adjust_file_list_train = false;
        if ~all( cellfun( @(x) exist(fullfile(experiment_settings.data_path_train,x),'file'), unique(vertcat(data_folds.fnames_lb_train)) ) )
            warning('training images from split file do not all exist in the training directory. using all files in the training image directory');
            temp = dir( fullfile( experiment_settings.data_path_train, '*.labl' ) );
            found_fnames = {temp.name}';
            for fi = 1:length(data_folds)
                data_folds(fi).fnames_lb_train = found_fnames;
                data_folds(fi).fnames_im_train = cellfun( @(x) [x(1:end-4) 'jpg'], found_fnames, 'UniformOutput', false );
            end
            needed_to_adjust_file_list_train = true;
        end

        needed_to_adjust_file_list_test = false;
        if ~all( cellfun( @(x) exist(fullfile(experiment_settings.data_path_test,x),'file'), unique(vertcat(data_folds.fnames_im_test)) ) )
            warning('testing images from split file do not all exist in the testing directory. using all files in the testing image directory');
            temp = dir( fullfile( experiment_settings.data_path_test, '*.jpg' ) );
            found_fnames = {temp.name}';
            for fi = 1:length(data_folds)
                data_folds(fi).fnames_im_test  = found_fnames;
                data_folds(fi).fnames_im_train = cellfun( @(x) [x(1:end-3) 'labl'], found_fnames, 'UniformOutput', false );
            end
            needed_to_adjust_file_list_test = true;
        end

        if (needed_to_adjust_file_list_train || needed_to_adjust_file_list_test) ...
        && isequal( experiment_settings.data_path_test, experiment_settings.data_path_train )
            generate_new_splits = true;
        end  
    end
   
    % generate new splits
    if generate_new_splits
        % this really only makes sense if there's a single directory that will be used for
        % validation, so we're just going to split up the experiment_settings.data_path_train data and use that

            if ~isequal(experiment_settings.data_path_train,experiment_settings.data_path_test)
                warning('ignoring experiment_settings.data_path_test variable and generating splits using just experiment_settings.data_path_train');
                experiment_settings.data_path_test = experiment_settings.data_path_train;
            end

        % genterate folds
            data_folds = generate_data_folds( experiment_settings.data_path_train, length(experiment_settings.folds), experiment_settings.testing_data_max );

         % save the splits to files
            if ~isdir(experiment_settings.results_directory), mkdir(experiment_settings.results_directory); end
            for i = 1:length(data_folds)
                fname_train_out = fullfile(experiment_settings.results_directory, [experiment_settings.title '_fnames_split_' num2str(i,'%02d') '_train.txt']);
                fid_train = fopen(fname_train_out,'w+');
                fprintf(fid_train,'%s\n',data_folds(i).fnames_lb_train{:});
                fclose(fid_train);

                fname_test_out  = fullfile(experiment_settings.results_directory, [experiment_settings.title '_fnames_split_' num2str(i,'%02d') '_test.txt' ]);
                fid_test  = fopen(fname_test_out, 'w+');
                fprintf(fid_test, '%s\n',data_folds(i).fnames_lb_test{:} );
                fclose(fid_test);
            end 
            
    end
        
    % apply limits to training/testing set sizes
    %   if there was a limit on the number of testing images (which is interpretted as per-fold),
    %   or on the number of training images,
    %   adjust the data_folds struct to reflect that

        if isempty(experiment_settings.testing_data_max)
            experiment_settings.testing_data_max = length(data_folds(1).fnames_im_test);
        end
    
        if experiment_settings.testing_data_max < length(data_folds(1).fnames_im_test)
            for i = 1:length(data_folds)
                data_folds(i).fnames_lb_test = data_folds(i).fnames_lb_test(1:experiment_settings.testing_data_max);
                data_folds(i).fnames_im_test = data_folds(i).fnames_im_test(1:experiment_settings.testing_data_max);
            end
        end

        if isfield(experiment_settings,'training_data_max') && ~isempty(experiment_settings.training_data_max) && experiment_settings.training_data_max > 0
            for i = 1:length(data_folds)
                data_folds(i).fnames_lb_train = data_folds(i).fnames_lb_train(1:experiment_settings.training_data_max);
                data_folds(i).fnames_im_train = data_folds(i).fnames_im_train(1:experiment_settings.training_data_max);
            end
        end
        
        
        
%% run the main experiment loop (experimental conditions, images) 

    for fold_ind = experiment_settings.folds
        
        learned_models = []; % contains everything we gather from training data, so is reset at the start of each fold
        learned_models_training_functions = [];

        % get training and testing file names for the current fold (and validate)
        %   (although not used, these are saved into results that are saved off)
            fnames_lb_train = cellfun( @(x) fullfile(experiment_settings.data_path_train, x), data_folds(fold_ind).fnames_lb_train, 'UniformOutput', false );
            fnames_im_test  = cellfun( @(x) fullfile(experiment_settings.data_path_test,  x), data_folds(fold_ind).fnames_im_test,  'UniformOutput', false );
            
            [~,~,~,failed_inds] = situate.validate_training_data( fnames_lb_train, parameterization_conditions(1) );
            if any(failed_inds)
                display('the following training images failed validation');
                display(fnames_lb_train(failed_inds));
                error('training label files failed validation');
            end
            fnames_lb_train(failed_inds) = [];
            
        % loop through experimental settings
        
            for parameters_ind = 1:length(parameterization_conditions)

                cur_parameterization = parameterization_conditions(parameters_ind);
                rng( cur_parameterization.seed_test );
                
                % load or learn the situation model
                if ~isfield( learned_models, 'situation_model') ...
                || ~isequal( learned_models_training_functions.situation, cur_parameterization.situation_model.learn )
                    learned_models_training_functions.situation = cur_parameterization.situation_model.learn;
                    learned_models.situation_model.joint = ...
                        cur_parameterization.situation_model.learn( ...
                            cur_parameterization, ...
                            fnames_lb_train );
                end

                % load or learn the classification models
                if ~isfield( learned_models, 'classifier_model') ...
                || ~isequal( learned_models_training_functions.classifier, cur_parameterization.classifier.train )
                    learned_models_training_functions.classifier = cur_parameterization.classifier.train;
                    learned_models.classifier_model = ...
                        cur_parameterization.classifier.train( ...
                            cur_parameterization, ...
                            fnames_lb_train, ...
                            cur_parameterization.classifier.directory );
                end

                % load or learn the adjustment model
                % train( fnames_in, saved_models_directory, IOU_threshold_for_training )
                if ~isfield(learned_models, 'adjustment_model') ...
                || ~isequal( learned_models_training_functions.adjustment, cur_parameterization.adjustment_model.train )
                    learned_models_training_functions.adjustment = cur_parameterization.adjustment_model.train;
                    learned_models.adjustment_model = ...
                        cur_parameterization.adjustment_model.train( ...
                            cur_parameterization, ...
                            fnames_lb_train, ...
                            cur_parameterization.adjustment_model.directory);
                end

                progress( 0, length(fnames_im_test),cur_parameterization.description); 

                % loop through images
                workspaces_final    = cell(1,length(fnames_im_test));
                agent_records       = cell(1,length(fnames_im_test));
                
                if isempty( experiment_settings.testing_data_max ), experiment_settings.testing_data_max = length(fnames_im_test); end
                parfor cur_image_ind = 1:experiment_settings.testing_data_max
                    
                    % run on the current image
                    cur_fname_im = fnames_im_test{cur_image_ind};

                    tic;
                    [ ~, run_data_cur ] = situate.main_loop( cur_fname_im, cur_parameterization, learned_models );

                    % store results
                    workspaces_final{cur_image_ind} = run_data_cur.workspace_final;
                    agent_records{cur_image_ind}    = run_data_cur.agent_record;

                    % display an update in the console
                    num_iterations_run = sum(~eq(0,[run_data_cur.agent_record.interest]));
                    [~,sort_order] = sort( run_data_cur.workspace_final.labels );
                    IOUs_of_last_run   = num2str(run_data_cur.workspace_final.GT_IOU(sort_order));
                    fprintf('%s, %3d / %d, %4d steps, %6.2fs,  IOUs: [%s] \n', cur_parameterization.description, cur_image_ind, length(fnames_im_test), num_iterations_run, toc, IOUs_of_last_run );
                    
                end

                % save off results every condition and fold
                %   current fold and 
                %   experimental condition
                save_fname = fullfile(experiment_settings.results_directory, [cur_parameterization.description '_fold_' num2str(fold_ind,'%02d') '_' datestr(now,'yyyy.mm.dd.HH.MM.SS') '.mat']);
                
                p_condition = cur_parameterization;
                p_condition_description = p_condition.description;
                
                save(save_fname, '-v7', ...
                'p_condition', ...
                'workspaces_final', ...
                'agent_records', ...
                'fnames_lb_train', ...
                'fnames_im_test' );

                display(['saved to ' save_fname]);
                    
            end
           
    end
  
    
    
end


function data_folds = generate_data_folds( data_path, num_folds, testing_data_max )

    % get the file names
        
        % get the label files
        dir_data = dir(fullfile(data_path, '*.labl'));
        fnames_lb = {dir_data.name};
        assert(~isempty(fnames_lb));
        
        % get the associated image files
        is_missing_image_file = false(1,length(fnames_lb));
        for fi = 1:length(fnames_lb)
            is_missing_image_file(fi) = ~exist( fullfile(data_path, [fnames_lb{fi}(1:end-5) '.jpg' ]),'file');
        end
        fnames_lb(is_missing_image_file) = [];
        
        % shuffle
        rp = randperm( length(fnames_lb) );
        fnames_lb = fnames_lb(rp);
        
    % generate training/testing splits for cross validation

        n = length(fnames_lb);
        step = floor( n / num_folds );
        fold_inds_start = (0:step:n-step)+1;
        fold_inds_end   = fold_inds_start + step - 1;
        
        if ~isempty(testing_data_max) && step > testing_data_max
            fold_inds_end = fold_inds_start + testing_data_max - 1;
            warning('situate.experiment_helper:using subset of available data');
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
        end
            
end


       
           

