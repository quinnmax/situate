function experiment_handler_parallel( experiment_struct, situation_struct, situate_params_array )

% experiment_handler_parallel( experiment_struct, situation_struct, situate_params_array );



    %% tidy up parameterizations 
      
        situate_params_array = situate.parameters_struct_new_to_old( experiment_struct, situation_struct, situate_params_array );
        assert( all( situate.parameters_struct_validate( situate_params_array ) ) );
        num_parameterizations = numel(situate_params_array);
        if (num_parameterizations == 1 && isempty( situate_params_array.seed_test )) || any(isempty([situate_params_array.seed_test]))
            rng('shuffle');
            cur_rng = rng();
            for parameters_ind = 1:num_parameterizations
                situate_params_array(parameters_ind).seed_test = cur_rng.Seed;
            end
            display(['testing seed was empty, set to: ' num2str(cur_rng.Seed)]);
        end
        
        
        
    %% generate training/testing sets 
    
    % see if the training/testing directories are using the base directories
    if ~exist(experiment_struct.experiment_settings.directory_train,'dir') ...
    || ~exist(experiment_struct.experiment_settings.directory_test,'dir')  ...

        base_image_directories = jsondecode_file('base_image_directories.json');
        base_image_directories = base_image_directories.base_dirs;
        if ~isempty(base_image_directories)
            
            if ~exist(experiment_struct.experiment_settings.directory_train,'dir')
                training_dirs = cellfun( @(x) exist( fullfile( x, experiment_struct.experiment_settings.directory_train ), 'dir' ), base_image_directories );
                experiment_struct.experiment_settings.directory_train = fullfile( base_image_directories{find(training_dirs,1,'first')}, experiment_struct.experiment_settings.directory_train );
            end
            
            if ~exist(experiment_struct.experiment_settings.directory_test,'dir')
                testing_dirs = cellfun( @(x) exist( fullfile( x, experiment_struct.experiment_settings.directory_test ), 'dir' ), base_image_directories );
                experiment_struct.experiment_settings.directory_test = fullfile( base_image_directories{find(testing_dirs,1,'first')}, experiment_struct.experiment_settings.directory_test );
            end
           
        else
            error('training/testing directories could not be reconciled with base image directory');
        end
    end
    
    train_test_dirs_match = isequal(  experiment_struct.experiment_settings.directory_train, experiment_struct.experiment_settings.directory_test );
    if isempty( experiment_struct.experiment_settings.training_testing_split_directory )
        have_training_split_dir = false;
    else
        if exist( experiment_struct.experiment_settings.training_testing_split_directory , 'dir' )
            have_training_split_dir = true;
        elseif exist( fullfile( 'data_splits', experiment_struct.experiment_settings.training_testing_split_directory), 'dir' )
            experiment_struct.experiment_settings.training_testing_split_directory = fullfile( 'data_splits', experiment_struct.experiment_settings.training_testing_split_directory);
            have_training_split_dir = true;
        else
            have_training_split_dir = false;
        end
    end

    if train_test_dirs_match && have_training_split_dir
        % load from saved splits
        data_split_struct = situate.data_load_splits_from_directory( experiment_struct.experiment_settings.training_testing_split_directory );
        display(['loaded training splits from: ' experiment_struct.experiment_settings.training_testing_split_directory]);
    end

    if train_test_dirs_match && ~have_training_split_dir
        % make new splits save them off
        data_path = experiment_struct.experiment_settings.directory_train;
        output_directory = fullfile('data_splits/', [situation_struct.desc '_' datestr(now,'yyyy.mm.dd.HH.MM.SS')]);
        num_folds = experiment_struct.experiment_settings.num_folds;
        max_images_per_fold = experiment_struct.experiment_settings.max_testing_images;
        if ~isempty(max_images_per_fold)
            data_split_struct = situate.data_generate_split_files( data_path, 'num_folds', num_folds, 'test_im_per_fold', max_images_per_fold, 'output_directory', output_directory );
        else
            data_split_struct = situate.data_generate_split_files( data_path, 'num_folds', num_folds, 'output_directory', output_directory );
        end
    end

    if ~train_test_dirs_match && ~have_training_split_dir
        % use everything in directories
        disp('using all images from training / testing directories');
        data_split_struct = [];
        data_split_struct.fnames_lb_train = arrayfun( @(x) x.name, dir(fullfile(experiment_struct.experiment_settings.directory_train, '*.json')), 'UniformOutput', false );
        data_split_struct.fnames_lb_test  = arrayfun( @(x) x.name, dir(fullfile(experiment_struct.experiment_settings.directory_test,  '*.json')), 'UniformOutput', false );
        data_split_struct.fnames_im_train = arrayfun( @(x) x.name, dir(fullfile(experiment_struct.experiment_settings.directory_train, '*.jpg')),  'UniformOutput', false );
        data_split_struct.fnames_im_test  = arrayfun( @(x) x.name, dir(fullfile(experiment_struct.experiment_settings.directory_test,  '*.jpg')),  'UniformOutput', false );
    end

    if ~train_test_dirs_match && have_training_split_dir
        % respect the provided splits
        data_split_struct = situate.data_load_splits_from_directory( experiment_struct.experiment_settings.training_testing_split_directory );
        display(['loaded training splits from: ' experiment_struct.experiment_settings.training_testing_split_directory]);
    end

    % if specific folds are specified, then limit to those folds
    if ~isfield(experiment_struct.experiment_settings,'specific_folds') || isempty(experiment_struct.experiment_settings.specific_folds)
        fold_inds = 1:experiment_struct.experiment_settings.num_folds;
    else
        fold_inds = experiment_struct.experiment_settings.specific_folds;
    end

    % if a maximum number of testing images was specified, enforce here
    if ~isempty(experiment_struct.experiment_settings.max_testing_images)
        for fii = 1:length(fold_inds)
            fi = fold_inds(fii);
            if experiment_struct.experiment_settings.max_testing_images < length(data_split_struct(fi).fnames_lb_test)
                data_split_struct(fi).fnames_lb_test = data_split_struct(fi).fnames_lb_test(1 : experiment_struct.experiment_settings.max_testing_images );
                data_split_struct(fi).fnames_im_test = data_split_struct(fi).fnames_im_test(1 : experiment_struct.experiment_settings.max_testing_images );
            end
        end
    end

    % make sure all files exist in the specified directories
    %   note: turns out the third assertion is fine as fnames_lb_test may be empty, and
    %   assert( all( [] ) ) passes.
    for fii = 1:length(fold_inds)
        fi = fold_inds(fii);
        
        full_file_lb_train = cellfun( @(x) fullfile( experiment_struct.experiment_settings.directory_train, x), data_split_struct(fi).fnames_lb_train, 'UniformOutput', false );
        full_file_im_train = cellfun( @(x) fullfile( experiment_struct.experiment_settings.directory_train, x), data_split_struct(fi).fnames_im_train, 'UniformOutput', false );
        full_file_lb_test  = cellfun( @(x) fullfile( experiment_struct.experiment_settings.directory_test, x),  data_split_struct(fi).fnames_lb_test,  'UniformOutput', false );
        full_file_im_test  = cellfun( @(x) fullfile( experiment_struct.experiment_settings.directory_test, x),  data_split_struct(fi).fnames_im_test,  'UniformOutput', false );
        expected_files = [full_file_lb_train; full_file_im_train; full_file_lb_test; full_file_im_test];
        expected_files_exist = cellfun( @(x) exist(x,'file'), expected_files );
        
        if any( ~expected_files_exist )
            warning('expected files not found');
            display( expected_files( ~expected_files_exist ) );
            error('expected files not found');
        end
           
    end

    % make sure all training labels and images have their partners
    for fii = 1:length(fold_inds)
        fi = fold_inds(fii);
        assert( isequal( ...
            sort(cellfun( @(x) x(1:strfind(x,'.')), data_split_struct(fi).fnames_lb_train, 'UniformOutput', false )), ...
            sort(cellfun( @(x) x(1:strfind(x,'.')), data_split_struct(fi).fnames_im_train, 'UniformOutput', false )) ) );
    end


        
    %% run through it all 

    for fii = 1:length(fold_inds)
    
        fi = fold_inds(fii);

        learned_models = []; % contains everything we gather from training data, so is reset at the start of each fold
        learned_models_training_functions = []; % used to see if we can skip on re-training models

        fnames_lb_train = cellfun( @(x) fullfile(experiment_struct.experiment_settings.directory_train, x), data_split_struct(fi).fnames_lb_train, 'UniformOutput', false );
        fnames_im_test  = cellfun( @(x) fullfile(experiment_struct.experiment_settings.directory_test,  x), data_split_struct(fi).fnames_im_test,  'UniformOutput', false );
        
        if isempty( experiment_struct.experiment_settings.max_testing_images )
            experiment_struct.experiment_settings.max_testing_images = length(fnames_im_test);
        end
        num_images = experiment_struct.experiment_settings.max_testing_images;
        
        [~, fnames_fail, exceptions, failed_inds] = situate.labl_validate( fnames_lb_train, situation_struct );
        if ~isempty(fnames_fail)
            error('some label files failed validation');
        end
        
        % loop through experimental settings
        for parameters_ind = 1:length(situate_params_array)

            cur_parameterization = situate_params_array(parameters_ind);
            rng( cur_parameterization.seed_test );
            
            % load or learn the situation model
            if ~isfield( learned_models, 'situation_model') ...
            || ~isequal( learned_models_training_functions.situation, cur_parameterization.situation_model.learn )
                learned_models_training_functions.situation = cur_parameterization.situation_model.learn;
                learned_models.situation_model = ...
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

            fprintf(['params                           image       steps      time(s)            [ '  repmat('%-15s',1,3) '] \n'], situation_struct.situation_objects{:})
            parfor cur_image_ind = 1:experiment_struct.experiment_settings.max_testing_images

                % run on the current image
                cur_fname_im = fnames_im_test{cur_image_ind};

                tic;
                [ ~, run_data_cur ] = situate.main_loop( cur_fname_im, cur_parameterization, learned_models );

                % try to reconcile workspace with GT boxes
                cur_fname_lb = [fileparts_mq(cur_fname_im,'path/name') '.json'];
                if exist(cur_fname_lb,'file')
                    reconciled_workspace = situate.workspace_score(run_data_cur.workspace_final, cur_fname_lb, cur_parameterization );
                else
                    reconciled_workspace = run_data_cur.workspace_final;
                end
                
                labels_missed = setdiff(cur_parameterization.situation_objects,run_data_cur.workspace_final.labels);
                labels_temp = [run_data_cur.workspace_final.labels labels_missed];
                GT_IOUs = [reconciled_workspace.GT_IOU nan(1,length(labels_missed))];
                [~,sort_order_2] = sort( labels_temp );
                [~,sort_order_1] = sort( cur_parameterization.situation_objects);
                IOUs_of_last_run = sprintf(repmat('%1.4f         ',1,length(GT_IOUs)),GT_IOUs(sort_order_2(sort_order_1)));
                
                % display update to console
                num_iterations_run = sum(~eq(0,[run_data_cur.agent_record.interest]));
                fprintf('%-28s %3d /%4d        %4d      %6.2f       IOUs: [ %s] \n', ...
                    cur_parameterization.description, ...
                    cur_image_ind, ...
                    num_images, ...
                    num_iterations_run, ...
                    toc, ...
                    IOUs_of_last_run );
                
                % store results
                workspaces_final{cur_image_ind} = run_data_cur.workspace_final;
                agent_records{cur_image_ind}    = run_data_cur.agent_record;

            end

            % save off results, each condition and fold pair gets a file
            cur_param_desc = fileparts_mq(cur_parameterization.description,'name');
            save_fname = fullfile(experiment_struct.results_directory, [cur_param_desc '_fold_' num2str(fi,'%02d') '_' datestr(now,'yyyy.mm.dd.HH.MM.SS') '.mat']);

            results_struct = [];
            results_struct.p_condition      = cur_parameterization;
            results_struct.workspaces_final = workspaces_final;
            results_struct.agent_records    = agent_records;
            results_struct.fnames_lb_train  = fnames_lb_train;
            results_struct.fnames_im_test   = fnames_im_test;

            save(save_fname, '-v7', '-struct','results_struct');
            fprintf('saved to:\n    %s\n', save_fname);

        end

    end

    
    
end


