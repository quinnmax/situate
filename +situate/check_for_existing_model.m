
function selected_model_fname = situate_check_for_existing_model( model_directory, fnames_train_in )

    selected_model_fname = '';

    % get the input training fnames, no path, sorted
    fnames_train = cell(size(fnames_train_in));
    for fi = 1:length(fnames_train)
        [~,fname_no_path] = fileparts( fnames_train_in{fi} );
        fnames_train{fi} = fname_no_path;
    end
    fnames_train = sort(fnames_train);


    % for each model in the directory
    model_files = dir(fullfile(model_directory, '*.mat'));
    for mi = 1:length(model_files)

        % get the training fnames, no path, sorted
        temp = load(fullfile(model_directory, model_files(mi).name), 'fnames_lb_train');
        if isfield(temp,'fnames_lb_train')
            model_fnames_train = temp.fnames_lb_train;
            for fi = 1:length(model_fnames_train)
                [~,fname_no_path] = fileparts( model_fnames_train{fi} );
                model_fnames_train{fi} = fname_no_path;
            end
            model_fnames_train = sort(model_fnames_train);

            if isequal(fnames_train, model_fnames_train )
                % we have a good model, return it somehow. maybe just its file name
                selected_model_fname = fullfile(model_directory, model_files(mi).name);
            end
        end
    end

    % if we got to here, we didn't find a good model, just going to return
    % the empty return_val
    
end
    
    
    







