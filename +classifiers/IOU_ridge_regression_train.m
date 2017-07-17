function classifier_model = IOU_ridge_regression_train( p, fnames_in, saved_models_directory )

    % classifier_model = cnnsvm_train( p, fnames_in, saved_models_directory );

    model_description = 'IOU ridge regression';
    possible_paths = { saved_models_directory };
    
    fnames_in_pathless = cell(size(fnames_in));
    for fi = 1:length(fnames_in)
        [~,name,ext] = fileparts(fnames_in{fi});
        fnames_in_pathless{fi} = [name ext];
    end
    
    selected_model_fname = situate.check_for_existing_model( possible_paths, 'fnames_lb_train', fnames_in_pathless, 'model_description', model_description );
    
    model_already_existed = ~isempty(selected_model_fname);
    if model_already_existed
       loaded_data = load( selected_model_fname );
       models = loaded_data.models;
       display(['loaded ' model_description ' model from: ' selected_model_fname ]);
    else
        
        % see if we have pre-existing features, or if we need to extract them
        existing_feature_directory = 'pre_extracted_feature_data';
        temp = dir(fullfile(existing_feature_directory,'*.mat'));
        if ~isempty(temp)
            existing_features_fname = fullfile( existing_feature_directory, temp(1).name );
        else
            existing_features_fname = cnn_feature_extractor( [], existing_feature_directory, p );
        end
        models = classifiers.create_IOU_ridge_regression_model_pre_extracted_features( fnames_in, existing_features_fname, p );
       
    end
    
    classifier_model.models            = models;
    classifier_model.classes           = p.situation_objects;
    classifier_model.fnames_lb_train   = fnames_in_pathless;
    classifier_model.model_description = model_description;
    
    if ~model_already_existed
        saved_model_fname = fullfile( saved_models_directory, [model_description '_' datestr(now,'yyyy.mm.dd.HH.MM.SS') '.mat'] );
        save(saved_model_fname,'-struct','classifier_model');
        display(['saved cnnsvm model to: ' saved_model_fname ]);
    end

end
    
    
    
            
        
        
        