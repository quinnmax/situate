
function classifier_struct = IOU_ridge_regression_train( situation_struct, fnames_in, saved_models_directory )



    % classifier_struct = classifiers.IOU_ridge_regression_train( situation_struct, fnames_in, saved_models_directory )

    model_description = 'IOU ridge regression';
    
    fnames_in_stripped = fileparts_mq( fnames_in, 'name');
    
    classes = situation_struct.situation_objects;
    
    
    
    %% check for existing model
    
        selected_model_fname = ...
            situate.check_for_existing_model( saved_models_directory, ...
            'fnames_lb_train', sort(fnames_in_stripped), ...
            'model_description', model_description, ...
            'classes', classes );

        if ~isempty(selected_model_fname)

            loaded_data = load( selected_model_fname );
            models = loaded_data.models;
            AUROCs = loaded_data.AUROCs;
            display(['loaded ' model_description ' model from: ' selected_model_fname ]);

            classifier_struct                   = [];
            classifier_struct.models            = models;
            classifier_struct.classes           = classes;
            classifier_struct.fnames_lb_train   = fnames_in_stripped;
            classifier_struct.model_description = model_description;
            classifier_struct.AUROCs            = AUROCs;

            return;

        end

        disp('training IOU ridge regression model');
    
        
        
    %% load or generate crops
    
        % see if we have pre-existing features, or if we need to extract them
        existing_feature_directory = 'pre_extracted_feature_data';
        if ~exist(existing_feature_directory,'dir')
            mkdir(existing_feature_directory);
        end
        
        selected_datafile_fname = situate.check_for_existing_model( ...
            existing_feature_directory, 'object_labels', sort(classes) );
        
        if ~isempty(selected_datafile_fname)
            display(['loading cnn feature data from ' selected_datafile_fname]);
            existing_features_fname = selected_datafile_fname;
        else
            disp('extracting cnn feature data');
            existing_features_fname = cnn.feature_extractor_bulk( fileparts(fnames_in{1}), existing_feature_directory, situation_struct );
        end
        
        % this crop extractor works on all images in the directory, not just the specified images.
        % it saves some time if we're doing multiple folds of the data and need to re-train some
        % models, but it means we need to be careful about only loading crops from the specified 
        % training images for actually training the model
    
        data = load(existing_features_fname);
        
        
        
    %% train the model
        
        training_image_inds = find(ismember( fileparts_mq( data.fnames, 'name' ), fileparts_mq( fnames_in, 'name' )));
        if isempty(training_image_inds)
            error('no images');
        end
        rows_train  = ismember(data.fname_source_index, training_image_inds );
        
        crop_size_threshold_px = 4096;
        crop_wh     = [data.box_proposals_r0rfc0cf(:,2)-data.box_proposals_r0rfc0cf(:,1)+1 data.box_proposals_r0rfc0cf(:,4)-data.box_proposals_r0rfc0cf(:,3)+1];
        crop_size_px = crop_wh(:,1) .* crop_wh(:,2);
        small_source_inds   =  crop_size_px < crop_size_threshold_px ;

        assert(isequal( sort(data.object_labels), sort(classes) ));
        models = cell( length(classes), 1 );
        scores = cell( length(classes), 1 );
        AUROCs = zeros(1,length(classes));
        
        for oi = 1:length(classes)
            
            obj_inds = data.box_source_obj_type == find(strcmp(classes{oi}, data.object_labels));
            inds_train = find( rows_train & obj_inds & ~small_source_inds );
            
            % do trust round on 80% of the data
            inds_train_trust = inds_train(1:round(.8*length(inds_train)));
            inds_test_trust  = setdiff( inds_train, inds_train_trust );
            x = data.box_proposal_cnn_features( inds_train_trust, : );
            y = data.IOUs_with_source( inds_train_trust );
            temp_model = ridge( y, x, 1000, 0 );
            
            x = data.box_proposal_cnn_features( inds_test_trust, : );
            y = data.IOUs_with_source( inds_test_trust );
            temp_scores = [ones(size(x,1),1) x] * temp_model;
            % record trust
            AUROCs(oi)  = ROC( temp_scores, y>=.5 );
            
            % then retrain on full data
            x = data.box_proposal_cnn_features( inds_train, : );
            y = data.IOUs_with_source( inds_train );
            models{oi} = ridge( y, x, 1000, 0 );
            
        end
      
        classifier_struct                   = [];
        classifier_struct.models            = models;
        classifier_struct.classes           = classes;
        classifier_struct.fnames_lb_train   = fnames_in_stripped;
        classifier_struct.model_description = model_description;
        classifier_struct.AUROCs            = AUROCs;

        
        
    %% save the model
        
        iter = 0;
        saved_model_fname = fullfile( saved_models_directory, [ [classes{:}] ', ' model_description ', ' num2str(iter) '.mat'] );
        while exist(saved_model_fname,'file')
            iter = iter + 1;
            saved_model_fname = fullfile( saved_models_directory, [ [classes{:}] ', ' model_description ', ' num2str(iter) '.mat'] );
        end
        save(saved_model_fname,'-struct','classifier_struct');
        display(['saved ' model_description ' model to: ' saved_model_fname ]);

        
        
end
    
    
    
            
        
        
        