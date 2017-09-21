function classifier_struct = cnnsvm_train( p, fnames_in, saved_models_directory )

    % classifier_struct = cnnsvm_train( p, fnames_in, saved_models_directory );

    model_description = 'cnnsvm';
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
       display(['loaded cnnsvm model from: ' selected_model_fname ]);
    else
        %models = cnn.create_cnn_svm_models_iterative( fnames_in, p );
        display(['training cnnsvm model']);
        tic
        models = cnn.create_cnn_svm_model_pre_extracted_features( fnames_in, p );
        toc
    end
    
    classifier_struct.models            = models;
    classifier_struct.classes           = p.situation_objects;
    classifier_struct.fnames_lb_train   = fnames_in_pathless;
    classifier_struct.model_description = model_description;
    
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
    
    
    
            
        
        
        