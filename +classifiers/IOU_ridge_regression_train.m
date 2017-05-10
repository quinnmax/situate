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
        %error('don''t have a training function for the IOU regressor');
        %display(['training cnnsvm model']);
        tic
        models = classifiers.create_IOU_ridge_regression_model_pre_extracted_features( fnames_in, p );
        toc
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
    
    
    
            
        
        
        