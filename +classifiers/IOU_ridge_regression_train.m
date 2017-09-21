function classifier_struct = IOU_ridge_regression_train( p, fnames_in, saved_models_directory )

    % classifier_struct = cnnsvm_train( p, fnames_in, saved_models_directory );

    model_description = 'IOU ridge regression';
    possible_paths = { saved_models_directory };
    
    fnames_in_pathless = cell(size(fnames_in));
    for fi = 1:length(fnames_in)
        [~,name,ext] = fileparts(fnames_in{fi});
        fnames_in_pathless{fi} = [name ext];
    end
    
    selected_model_fname = situate.check_for_existing_model( possible_paths, 'fnames_lb_train', sort(fnames_in_pathless), 'model_description', model_description, 'classes', p.situation_objects );
    model_already_existed = ~isempty(selected_model_fname);
    if model_already_existed
       loaded_data = load( selected_model_fname );
       models = loaded_data.models;
       AUROCs = loaded_data.AUROCs;
       display(['loaded ' model_description ' model from: ' selected_model_fname ]);
    else
        
        display('training IOU ridge regression model');
        
        % see if we have pre-existing features, or if we need to extract them
        existing_feature_directory = 'pre_extracted_feature_data';
        if ~exist(existing_feature_directory,'dir')
            mkdir(existing_feature_directory);
        end
        
        selected_datafile_fname = situate.check_for_existing_model( ...
            existing_feature_directory, 'object_labels', sort(p.situation_objects) );
        
        if ~isempty(selected_datafile_fname)
            display(['loaded cnn feature data from ' selected_datafile_fname]);
            existing_features_fname = selected_datafile_fname;
        else
            display('extracting cnn feature data');
            existing_features_fname = cnn_feature_extractor( fileparts(fnames_in{1}), existing_feature_directory, p );
        end
        [models,AUROCs] = classifiers.create_IOU_ridge_regression_model_pre_extracted_features( fnames_in, existing_features_fname, p );
       
    end
    
    classifier_struct.models            = models;
    classifier_struct.classes           = p.situation_objects;
    classifier_struct.fnames_lb_train   = fnames_in_pathless;
    classifier_struct.model_description = model_description;
    classifier_struct.AUROCs            = AUROCs;
    
    if ~model_already_existed
        iter = 0;
        saved_model_fname = fullfile( saved_models_directory, [ [p.situation_objects{:}] ', ' model_description ', ' num2str(iter) '.mat'] );
        while exist(saved_model_fname,'file')
            iter = iter + 1;
            saved_model_fname = fullfile( saved_models_directory, [ [p.situation_objects{:}] ', ' model_description ', ' num2str(iter) '.mat'] );
        end
        save(saved_model_fname,'-struct','classifier_struct');
        display(['saved ' model_description ' model to: ' saved_model_fname ]);
    end

end
    
    
    
            
        
        
        