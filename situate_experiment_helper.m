
    
function [] = situate_experiment_helper(experiment_settings, p_conditions, situate_data_path, split_arg)
% situate_experiment_helper(experiment_settings, p_conditions, situate_data_path, split_arg)



%% deal with split_arg data

    if exist('split_arg','var') && ~isempty(split_arg)
        if isnumeric(split_arg)
            % we'll interpret it as a seed value
            rng(split_arg);
        elseif ischar(split_arg) && isdir(split_arg)
            % then it's a directory, we'll look for split_files to use
            split_file_directory = split_arg;
        else
            % don't rightly know
            error('don''t know what to do with that split_arg');
        end
    else
        warning('split_arg_was empty, using current time as rng seed for testing');
        rng(now);
    end

    
  
%% set training and testing sets
  
    fname_blacklist = {}; 
    % fname_blacklist should be used if there's some saved off model that 
    % we want to mess with. 
    % Everything in the fname_blacklist will be excluded from both the
    % training and testing images that are used for learning the
    % conditional model stuff
    
    if exist('split_file_directory','var') && isdir(split_file_directory)
        
        % Load the splits rather than generating new ones
        % edit: currently looks for the existing experiment name in the
        % title of the split file. not sure that that should be necessary.
        % something to think about and adjust in the future
        
        fnames_splits_train = dir(fullfile(split_file_directory, '*_fnames_split_*_train.txt'));
        fnames_splits_test  = dir(fullfile(split_file_directory, '*_fnames_split_*_test.txt' ));
        fnames_splits_train = cellfun( @(x) fullfile(split_file_directory, x), {fnames_splits_train.name}, 'UniformOutput', false );
        fnames_splits_test  = cellfun( @(x) fullfile(split_file_directory, x), {fnames_splits_test.name},  'UniformOutput', false );
        assert( length(fnames_splits_train) > 0 );
        assert( length(fnames_splits_train) == length(fnames_splits_test) );
        fprintf('using training splits from:\n');
        fprintf('\t%s\n',fnames_splits_train{:});
        fprintf('using testing splits from:\n');
        fprintf('\t%s\n',fnames_splits_test{:});
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
           
    else % generate splits based on situate_data_path, experiment_settings.training_data_max, experiment_settings.testing_data_max
        
        % generate new splits, and save the files to the split-file directory.
        
            % get the label files
            dir_data = dir(fullfile(situate_data_path, '*.labl'));
            fnames_lb = {dir_data.name};
            assert(~isempty(fnames_lb));
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
            step = floor( n / experiment_settings.num_folds );
            fold_inds_start = (0:step:n-step)+1;
            fold_inds_end   = fold_inds_start + step - 1;
            if ~isempty(experiment_settings.testing_data_max) && step > experiment_settings.testing_data_max
                fold_inds_end = fold_inds_start + experiment_settings.testing_data_max - 1;
                warning('situate_experiment:using subset of available data');
            end

            data_folds = [];
            data_folds.fnames_im_train = [];
            data_folds.fnames_im_test  = [];
            data_folds.fnames_lb_train = [];
            data_folds.fnames_lb_test  = [];
            data_folds = repmat(data_folds,1,experiment_settings.num_folds);
            for i = 1:experiment_settings.num_folds
                data_folds(i).fnames_lb_test  = fnames_lb( fold_inds_start(i):fold_inds_end(i) );
                data_folds(i).fnames_lb_train = setdiff( fnames_lb, data_folds(i).fnames_lb_test );
                data_folds(i).fnames_im_test  = cellfun( @(x) [x(1:end-5) '.jpg'], data_folds(i).fnames_lb_test,  'UniformOutput', false );
                data_folds(i).fnames_im_train = cellfun( @(x) [x(1:end-5) '.jpg'], data_folds(i).fnames_lb_train, 'UniformOutput', false );
            end

        % save splits to files (if not use gui)
            if ~experiment_settings.use_gui
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
           
    end 
    
    if ~isempty(experiment_settings.testing_data_max) && experiment_settings.testing_data_max < length(data_folds(i).fnames_lb_test)
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
    
    if experiment_settings.perform_situate_run_on_training_data
        for fold_ind = 1:length(data_folds)
            data_folds(fold_ind).fnames_lb_test = data_folds(fold_ind).fnames_lb_train;
            data_folds(fold_ind).fnames_im_test = data_folds(fold_ind).fnames_im_train;
        end
    end

    
    
%% run the main loop 

    for fold_ind = 1:experiment_settings.num_folds
        
        learned_stuff = []; % contains everything we gather from training data, so is reset at the start of each fold
        
        % get current training and testing file names
        
            fnames_lb_test  = cellfun( @(x) fullfile(situate_data_path, x), data_folds(fold_ind).fnames_lb_test,  'UniformOutput', false );
            fnames_im_test  = cellfun( @(x) fullfile(situate_data_path, x), data_folds(fold_ind).fnames_im_test,  'UniformOutput', false );
            fnames_lb_train = cellfun( @(x) fullfile(situate_data_path, x), data_folds(fold_ind).fnames_lb_train, 'UniformOutput', false );
            fnames_im_train = cellfun( @(x) fullfile(situate_data_path, x), data_folds(fold_ind).fnames_im_train, 'UniformOutput', false );
            [fnames_lb_train_pass, fnames_lb_train_fail, exceptions, failed_inds] = situate_validate_training_data( fnames_lb_train, p_conditions(1) );
            if any(failed_inds)
                display('the following training images failed validation');
                display(fnames_lb_train(failed_inds));
                error('training label files failed validation');
            end
            fnames_lb_train(failed_inds) = [];
            fnames_im_train(failed_inds) = [];
            
        % run through experimental settings
        
            workspaces_final    = cell(length(p_conditions),length(fnames_im_test));
            agent_records       = cell(length(p_conditions),length(fnames_im_test));
            run_data            = cell(length(p_conditions),length(fnames_im_test));
            
            for experiment_ind = 1:length(p_conditions)

                cur_experiment_parameters = p_conditions(experiment_ind);
                
                rng( cur_experiment_parameters.seed_test );
                            
                progress( 0, length(fnames_im_test),cur_experiment_parameters.description); 
                
                cur_image_ind  = 1;
                keep_going = true;
                while keep_going
                    
                    if experiment_settings.use_gui
                    % get changes to the running parameters using the
                    % parameters GUI
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
                    
                    learned_stuff = load_or_build_models( cur_experiment_parameters, fnames_lb_train, learned_stuff );
                   
                    % run on the current image
                    cur_fname_im = fnames_im_test{cur_image_ind};
  
                    if cur_experiment_parameters.rcnn_boxes
                        assert( isequal(experiment_settings.situation,'dogwalking')...
                            || isequal(experiment_settings.situation,'dogwalking_no_leash'));
                        % grab the rcnn boxes for this particular image
                        faster_rcnn_data          = load_faster_rcnn_data(cur_fname_im);
                        [~,linear_scaling_factor] = imresize_px( imread(cur_fname_im), cur_experiment_parameters.image_redim_px );
                        faster_rcnn_data.boxes_xywh = linear_scaling_factor * double( faster_rcnn_data.boxes_xywh );
                        learned_stuff.faster_rcnn_data = faster_rcnn_data;
                    end
                    
                    tic;
                    [ ~, run_data_cur, visualizer_status_string ] = situate_sketch( cur_fname_im, cur_experiment_parameters, learned_stuff );
                    
                    if ~experiment_settings.use_gui
                        run_data{experiment_ind,cur_image_ind}         = run_data_cur;
                        workspaces_final{experiment_ind,cur_image_ind} = run_data_cur.workspace_final;
                        agent_records{experiment_ind,cur_image_ind}    = run_data_cur.agent_record;
                    end
                    
                    num_iterations_run = sum(cellfun(@(x) ~isempty(x),{run_data_cur.agent_record.interest}));
                    progress_string = [cur_experiment_parameters.description ', ' num2str(num_iterations_run), ' steps, ' num2str(toc) 's'];
                    progress(cur_image_ind,length(fnames_im_test),progress_string);
                   
                    % deal with GUI responses
                    if experiment_settings.use_gui

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

                        if cur_image_ind > experiment_settings.testing_data_max
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

                if experiment_settings.use_gui
                    % bail after the first experimental setup if we're using the GUI
                    break;
                end

            end

        if experiment_settings.use_gui
            % bail after the first fold if we're using the GUI
            break; 
        else
            p_conditions_descriptions = {p_conditions.description};
            if experiment_settings.perform_situate_run_on_training_data
                save_fname = fullfile(experiment_settings.results_directory, [experiment_settings.title '_training_data_run' '_split_' num2str(fold_ind,'%02d') '_' datestr(now,'yyyy.mm.dd.HH.MM.SS') '.mat']);
            else
                save_fname = fullfile(experiment_settings.results_directory, [experiment_settings.title '_split_' num2str(fold_ind,'%02d') '_' datestr(now,'yyyy.mm.dd.HH.MM.SS') '.mat']);
            end
            save(save_fname, ...
                'p_conditions', ...
                'workspaces_final', ...
                'agent_records', ...
                'fnames_im_train', ...
                'fnames_im_test',...
                'fnames_lb_train', ...
                'fnames_lb_test',...
                'run_data');
            
                %'p_conditions_descriptions', ...
                
            display(['saved to ' save_fname]);
        end
        
    end
    
    

end



function learned_stuff = load_or_build_models( cur_experiment_parameters, fnames_lb_train, learned_stuff )

    % if either cnn or box_adjust are being used, check to see that 
    % matconvnet is working properly
        if any(strcmp([ cur_experiment_parameters.classification_method ],'CNN-SVM')) || any([ cur_experiment_parameters.use_box_adjust ])
            % see if matconvnet has been built. if not, see if we can
            % install it
            try 
                test_image = imread('cameraman.tif');
                test_image(:,:,2) = test_image(end:-1:1,:,1);
                test_image(:,:,3) = test_image(:,end:-1:1,1);
                dummy_data = cnn.cnn_process( test_image );
            catch
                original_dir = pwd;
                cd matconvnet;
                addpath matlab;
                vl_compilenn;
                run matlab/vl_setupnn;
                cd(original_dir);

                test_image = imread('cameraman.tif');
                test_image(:,:,2) = test_image(end:-1:1,:,1);
                test_image(:,:,3) = test_image(:,end:-1:1,1);
                dummy_data = cnn.cnn_process( test_image );
                
                % if it bonks again, you'll have to try something else
            end
        end

    % conditional distribution models
    if strncmp( 'mvn_conditional', cur_experiment_parameters.location_method_after_conditioning, length('mvn_conditional') ) ...
    || strncmp( 'conditional_mvn', cur_experiment_parameters.box_method_after_conditioning,      length('conditional_mvn') )
        learned_stuff.conditional_models_structure = situate_build_conditional_distribution_structure( fnames_lb_train, cur_experiment_parameters );
        % hack to make the current 4 object version work with 3 objects again
        if length(cur_experiment_parameters.situation_objects) == 3
            none_index_for_three_objects = 4;
            learned_stuff.conditional_models_structure.models = learned_stuff.conditional_models_structure.models(:,:,:,none_index_for_three_objects);
        end
    end
    
    % hog svm models
    if strcmp( 'HOG-SVM', cur_experiment_parameters.classification_method )
        if isfield(learned_stuff, 'hog_svm_models'), 
            % do nothing, it's already been dtrained with this data set
        else
            possible_paths = {...
                'default_models/',...
                '+hog_svm/'};
            existing_model_path_ind = find(cellfun(@(x) exist(x,'dir'),possible_paths), 1, 'first' );
            existing_model_path     = possible_paths{ existing_model_path_ind };
            existing_model_fname    = situate_check_for_existing_model( existing_model_path, fnames_lb_train );
            if ~isempty(existing_model_fname)
                learned_stuff.hog_svm_models = load(existing_model_fname);
                display('loaded hog-svm models');
            else % train the thing
                display('building hog-svm models');
                hog_svm_models = hog_svm.hog_svm_train(fnames_lb_train, cur_experiment_parameters);
                hog_svm_models.fnames_lb_train = fnames_lb_train;
                saved_model_fname = fullfile(existing_model_path, ['hog_svm_models_' datestr(now,'yyyy.mm.dd.HH.MM.SS') '.mat']);
                save( saved_model_fname, '-struct', 'hog_svm_models' );
                learned_stuff.hog_svm_models = hog_svm_models;
            end
        end
    end
    
    % cnn models
    if strcmp( 'CNN-SVM', cur_experiment_parameters.classification_method )
        if isfield(learned_stuff, 'cnn_svm_models'), 
            % do nothing, it's already been dtrained with this data set
        else
            possible_paths = {...
                'default_models/', ...
                '+cnn/'};
            existing_model_path_ind = find(cellfun(@(x) exist(x,'dir'),possible_paths), 1, 'first' );
            existing_model_path     = possible_paths{ existing_model_path_ind };
            existing_model_fname    = situate_check_for_existing_model( existing_model_path, fnames_lb_train );
            if ~isempty(existing_model_fname)
                learned_stuff.cnn_svm_models = load(existing_model_fname);
                display('loaded cnn-svm models');
            else
                display('building cnn-svm models');
                cnn_svm_models.models          = cnn.create_cnn_svm_models_iterative(fnames_lb_train, cur_experiment_parameters);
                cnn_svm_models.fnames_lb_train = fnames_lb_train;
                saved_model_fname = fullfile(existing_model_path, ['cnn_svm_models_' datestr(now,'yyyy.mm.dd.HH.MM.SS') '.mat']);
                save( saved_model_fname, '-struct', 'cnn_svm_models' );
                learned_stuff.cnn_svm_models = cnn_svm_models;
            end
        end
    end
      
     % box adjust models
    if cur_experiment_parameters.use_box_adjust
        if isfield(learned_stuff, 'box_adjust_models'), 
            % do nothing, it's already been dtrained with this data set
        else
            possible_paths = {...
                'default_models/', ...
                '+box_adjust/'};
            existing_model_path_ind = find(cellfun(@(x) exist(x,'dir'),possible_paths), 1, 'first' );
            existing_model_path     = possible_paths{ existing_model_path_ind };
            existing_model_fname    = situate_check_for_existing_model( existing_model_path, fnames_lb_train );
            if ~isempty(existing_model_fname)
                learned_stuff.box_adjust_models = load(existing_model_fname);
                display('loaded box-adjust models');
            else % train the thing
                display('building box-adjust models');
                box_adjust_models = box_adjust.build_box_adjust_models_mq( fnames_lb_train, cur_experiment_parameters );
                box_adjust_models.fnames_lb_train = fnames_lb_train;
                saved_model_fname = fullfile(existing_model_path, ['box_adjust_models_' datestr(now,'yyyy.mm.dd.HH.MM.SS') '.mat']);
                save( saved_model_fname, '-struct', 'box_adjust_models' );
                learned_stuff.box_adjust_models = box_adjust_models;
            end
        end
    end
    
end



function faster_rcnn_data_for_image = load_faster_rcnn_data(cur_fname_im)

    possible_files = { ...
        '/Users/Max/Dropbox/situate_snapshot_current/saved_models_rcnn_scores/faster_rcnn_boxes.mat', ...
        '/home/rsoiffer/Desktop/Dropbox/situate_snapshot_current/saved_models_rcnn_scores/faster_rcnn_boxes.mat'...
    };
    
    faster_rcnn_data_raw_ind = find( cellfun( @(x) exist(x,'file'), possible_files ), 1, 'first');
    faster_rcnn_data_filename = possible_files{faster_rcnn_data_raw_ind};
    
    [~,file,ext] = fileparts(cur_fname_im);
    cur_fname_im_no_path = [file ext];
    faster_rcnn_data_raw = load(faster_rcnn_data_filename);
    last = @(x) x(end);
    faster_rcnn_fnames_im  = cellfun( @(x) x( last(strfind(x,filesep()))+1 : end ), faster_rcnn_data_raw.im_names, 'UniformOutput', false );
    ind_keep = find(strcmp( faster_rcnn_fnames_im, cur_fname_im_no_path ));
    faster_rcnn_data_for_image = [];
    faster_rcnn_data_for_image.boxes_xywh = cell2mat(cellfun( @(x) x(:,1:4), faster_rcnn_data_raw.output(2,ind_keep)', 'UniformOutput', false));
    faster_rcnn_data_for_image.box_scores = cell2mat(cellfun( @(x) x(:,5),   faster_rcnn_data_raw.output(2,ind_keep)', 'UniformOutput', false));
    faster_rcnn_data_for_image.fnames_im  = faster_rcnn_fnames_im(ind_keep);
end


