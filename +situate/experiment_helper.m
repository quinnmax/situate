
    
function [] = experiment_helper(experiment_settings, parameterization_conditions, split_arg)
% experiment_helper(experiment_settings, p_conditions, split_arg)


  
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
            else
                % don't rightly know
                error('don''t know what to do with that split_arg');
            end
            
        else
            warning('split_arg_was empty, using current time as rng seed for defining training-testing split');
            rng(now);
        end
       
    % load or generate splits
    %   if the split_arg was a directory, load splits from them
    %   if it was numeric, make up new training/testing splits

        if exist('split_file_directory','var') && isdir(split_file_directory)
            data_folds = load_data_splits_from_directory( split_file_directory );
        else 
            generate_new_splits = true;
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
    
    
    
    % this logic is ridiculous
        
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

        if ~isempty(experiment_settings.testing_data_max) && experiment_settings.testing_data_max < length(data_folds(1).fnames_im_test)
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
                
                keep_going = true;
                cur_image_ind = 1;
                while keep_going
                    
                    % run on the current image
                    cur_fname_im = fnames_im_test{cur_image_ind};

                    tic;
                    [ ~, run_data_cur, visualizer_status_string ] = situate.main_loop( cur_fname_im, cur_parameterization, learned_models );

                    
                    if experiment_settings.use_gui % handle visualizer status

                        switch visualizer_status_string
                            case 'restart'
                                % keep_going = true;
                            case 'next_image'
                                % keep_going = true;
                                cur_image_ind = cur_image_ind + 1;
                            case 'stop'
                                keep_going = false;
                            otherwise
                                keep_going = false;
                                % because we probably killed it with a window close
                        end

                    else

                       % store results
                        workspaces_final{cur_image_ind} = run_data_cur.workspace_final;
                        agent_records{cur_image_ind}    = run_data_cur.agent_record;

                        % display an update in the console
                        num_iterations_run = sum(~eq(0,[run_data_cur.agent_record.interest]));
                        IOUs_of_last_run   = num2str(run_data_cur.workspace_final.GT_IOU);
                        progress_string    = [cur_parameterization.description ', ' num2str(num_iterations_run), ' steps, ' num2str(toc) 's,', ' IOUs: [' IOUs_of_last_run ']'];
                        progress(cur_image_ind,length(fnames_im_test),progress_string);
                        
                        cur_image_ind = cur_image_ind + 1;
                        
                    end

                    if cur_image_ind > experiment_settings.testing_data_max
                        keep_going = false;
                        if experiment_settings.use_gui
                            msgbox('out of testing images');
                        end
                    end

                    if ~keep_going
                        break;
                    end

                end

                % bail after the first experimental setup if we're using the GUI
                if experiment_settings.use_gui
                    break;
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
            
            % bail after the first fold if we're using the GUI
            if experiment_settings.use_gui
                break;
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


function data_folds = load_data_splits_from_directory( split_file_directory )

       % Load the folds from files rather than generating new ones

        fnames_splits_train = dir(fullfile(split_file_directory, '*_fnames_split_*_train.txt'));
        fnames_splits_test  = dir(fullfile(split_file_directory, '*_fnames_split_*_test.txt' ));
        fnames_splits_train = cellfun( @(x) fullfile(split_file_directory, x), {fnames_splits_train.name}, 'UniformOutput', false );
        fnames_splits_test  = cellfun( @(x) fullfile(split_file_directory, x), {fnames_splits_test.name},  'UniformOutput', false );

        assert( length(fnames_splits_train) > 0 );
        assert( length(fnames_splits_train) == length(fnames_splits_test) );

        fprintf('using training splits from: \t%s\n', fnames_splits_train{:});
        fprintf('using testing  splits from: \t%s\n', fnames_splits_test{:} );

        temp = [];
        temp.fnames_lb_train = cellfun( @(x) importdata(x, '\n'), fnames_splits_train, 'UniformOutput', false );
        temp.fnames_lb_test  = cellfun( @(x) importdata(x, '\n'), fnames_splits_test,  'UniformOutput', false );
        data_folds = [];
        for i = 1:length(temp.fnames_lb_train)
            data_folds(i).fnames_lb_train = temp.fnames_lb_train{i};
            data_folds(i).fnames_lb_test  = temp.fnames_lb_test{i};
            data_folds(i).fnames_im_train = cellfun( @(x) [x(1:end-4) 'jpg'], temp.fnames_lb_train{i}, 'UniformOutput', false );
            data_folds(i).fnames_im_test  = cellfun( @(x) [x(1:end-4) 'jpg'], temp.fnames_lb_test{i},  'UniformOutput', false );
        end

end
       
           

