function classifier_model = cnnsvm_train( p, fnames_in, saved_models_directory )

    % classifier_model = cnnsvm_train( p, fnames_in, saved_models_directory );

    model_description = 'cnnsvm';
    
    possible_paths = {...
        saved_models_directory, ...
        'default_models/', ...
        '+cnn/'};
    
    % look for an existing model (one with training images that match the
    % provided training images exactly (sans path))
    
    selected_model_fname = situate.check_for_existing_model( possible_paths, fnames_in );
    model_already_existed = ~isempty(selected_model_fname);
    if ~isempty(selected_model_fname)
       loaded_data = load( selected_model_fname );
       models = loaded_data.models;
       warning('cnnsvm_train: loading a classifier model without using model description');
    else
        models = cnn.create_cnn_svm_models_iterative( fnames_in, p );
    end
    
    classifier_model.models            = models;
    classifier_model.classes           = p.situation_objects;
    classifier_model.fnames_lb_train   = fnames_in;
    classifier_model.model_description = model_description;
    
    if ~model_already_existed
        saved_model_fname = fullfile( saved_models_directory, [model_description '_' datestr(now,'yyyy.mm.dd.HH.MM.SS') '.mat'] );
        save(saved_model_fname,'-struct','classifier_model');
    end

end
    
    
    
            
        
        
        