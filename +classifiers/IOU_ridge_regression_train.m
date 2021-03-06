
function classifier_struct = IOU_ridge_regression_train( situation_struct, fnames_in, saved_models_directory )

    % classifier_struct = classifiers.IOU_ridge_regression_train( situation_struct, fnames_in, saved_models_directory )

    
    
    model_description = 'IOU ridge regression';
    fnames_in_stripped = fileparts_mq( fnames_in, 'name');
    classes = situation_struct.situation_objects;
    
    
    
    %% check for empty training data
    
        if isempty( fnames_in_stripped )

            warning('training fnames were empty, using default IOU ridge regression model for dogwalking');
            selected_model_fname = 'saved_models/unit_test_classifier_IOU_ridge_regression.mat';
            loaded_data = load( selected_model_fname );
            models = loaded_data.models;
            AUROCs = loaded_data.AUROCs;
            disp(['loaded ' model_description ' model from: ' selected_model_fname ]);

            classifier_struct                   = [];
            classifier_struct.models            = models;
            classifier_struct.classes           = classes;
            classifier_struct.fnames_lb_train   = fnames_in_stripped;
            classifier_struct.model_description = model_description;
            classifier_struct.AUROCs            = AUROCs;

            return;
        end

    
    
    %% check for existing model
    
        if exist(saved_models_directory,'dir')
            selected_model_fname = ...
                situate.check_for_existing_model( saved_models_directory, ...
                'fnames_lb_train', fnames_in, @(a,b) isempty(setxor(fileparts_mq(a,'name'),fileparts_mq(b,'name'))), ...
                'model_description', model_description, @isequal, ...
                'classes', classes, @(a,b) isempty(setxor(a,b)) );
        else
            selected_model_fname = [];
        end

        if ~isempty(selected_model_fname)

            loaded_data = load( selected_model_fname );
            models = loaded_data.models;
            AUROCs = loaded_data.AUROCs;
            disp(['loaded ' model_description ' model from: ' selected_model_fname ]);

            classifier_struct                   = [];
            classifier_struct.models            = models;
            classifier_struct.classes           = classes;
            classifier_struct.fnames_lb_train   = fnames_in_stripped;
            classifier_struct.model_description = model_description;
            classifier_struct.AUROCs            = AUROCs;

            return;

        end

        
        
    %% load or generate crops
    
        disp('training IOU ridge regression model');
    
        % see if we have pre-existing features, or if we need to extract them
        existing_feature_directory = 'pre_extracted_feature_data';
        if ~exist(existing_feature_directory,'dir')
            mkdir(existing_feature_directory);
        end
        
        selected_datafile_fname = situate.check_for_existing_model( ...
            existing_feature_directory, ...
            'object_labels', classes,  @(a,b) isempty(setxor(a,b)), ...
            'fnames', fnames_in, @(a,b) all(ismember(fileparts_mq(a,'name'),fileparts_mq(b,'name'))) );
        
        % 'fnames', fnames_in, @(a,b) isempty(setxor(fileparts_mq(a,'name.ext'),fileparts_mq(b,'name.ext'))) );
        
        
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
        training_image_inds_validation = training_image_inds(1:round(.8*length(training_image_inds)));
        if isempty(training_image_inds)
            error('no images');
        end
        
        crop_size_threshold_px = 4096;
        crop_wh     = [data.box_proposals_r0rfc0cf(:,2)-data.box_proposals_r0rfc0cf(:,1)+1 data.box_proposals_r0rfc0cf(:,4)-data.box_proposals_r0rfc0cf(:,3)+1];
        crop_size_px = crop_wh(:,1) .* crop_wh(:,2);
        small_source_inds   =  crop_size_px < crop_size_threshold_px ;

        rows_train = ismember(data.fname_source_index, training_image_inds ) & ~small_source_inds;
        rows_train_validation = ismember(data.fname_source_index, training_image_inds_validation) & ~small_source_inds;
    
        % situation objects of same type
        object_equivalence_matrix = false(length(classes),length(classes));
        for oi = 1:length(classes)
        for oj = 1:length(classes)
            object_equivalence_matrix(oi,oj) = isequal( sort(situation_struct.situation_objects_possible_labels{oi}), sort(situation_struct.situation_objects_possible_labels{oj}) );
        end
        end
    
        assert(isequal( sort(data.object_labels), sort(classes) ));
        models = cell( length(classes), 1 );
        AUROCs = zeros(1,length(classes));
        model_validation_stats = cell(length(classes),1);
        
        for oi = 1:length(classes)
            
            data_obj_inds = ismember( data.object_labels, classes( object_equivalence_matrix(oi,:) ) );
            
            if find(object_equivalence_matrix(oi,:),1,'first') ~= oi
                % then we already trained a model for something in the set of equivalent objects
                models{oi} = models{find(object_equivalence_matrix(oi,:),1,'first')};
                AUROCs(oi) = AUROCs( find(object_equivalence_matrix(oi,:),1,'first') );
                continue;
            end
            
            % do trust round on 80% of the data
            disp(['training IOU estimation model, partial data round: ' classes{oi}]);
            x = data.box_proposal_cnn_features( rows_train_validation, : );
            y = max( data.IOUs_with_each_gt_obj( rows_train_validation, data_obj_inds ), [], 2);
            temp_model = ridge( y, x, 1000, 0 );
            
            disp(['evaluating IOU estimation model on holdout data: ' classes{oi}]);
            rows_test_validation = setdiff( find(rows_train), find(rows_train_validation) );
            x = data.box_proposal_cnn_features( rows_test_validation, : );
            y = max( data.IOUs_with_each_gt_obj( rows_test_validation, data_obj_inds ), [], 2);
            temp_scores = [ones(size(x,1),1) x] * temp_model;
            
            
            % record trust
            dist_stats_temp          = [];
            dist_stats_temp.mu       = [];
            dist_stats_temp.sigma    = [];
            dist_stats_temp.mu(1)    = mean(temp_scores(y<.01));
            dist_stats_temp.sigma(1) = std(temp_scores(y<.01));
            dist_stats_temp.mu(2)    = mean(temp_scores(y>.5));
            dist_stats_temp.sigma(2) = std(temp_scores(y>.5));
            dist_stats_temp.logreg_b = logregfit( temp_scores, y>.5);
            
            num_bins = 20;
            [bin_assignments,bin_edges,bin_centers] = bin_linear(temp_scores, num_bins );
            bin_p = nan(1,num_bins);
            for bi = 1:num_bins
                bin_p(bi) = mean( y(bin_assignments==bi) );
            end
            
            dist_stats_temp.bin_eges = bin_edges;
            dist_stats_temp.bin_eges = bin_centers;
            dist_stats_temp.bin_p = bin_p;
            dist_stats_temp.AUROC = ROC( temp_scores, y>=.5 );
            
            model_validation_stats{oi} = dist_stats_temp;
            
            AUROCs(oi) = ROC( temp_scores, y>=.5 );
            disp(['     AUROC: ' num2str(AUROCs(oi))]);
            
            
            
            
            % then retrain on full data
            disp(['training IOU estimation model, all data round: ' classes{oi}]);
            x = data.box_proposal_cnn_features( rows_train, : );
            y = max( data.IOUs_with_each_gt_obj( rows_train, data_obj_inds ), [], 2);
            models{oi} = ridge( y, x, 1000, 0 );
            
        end
      
        classifier_struct                        = [];
        classifier_struct.models                 = models;
        classifier_struct.classes                = classes;
        classifier_struct.fnames_lb_train        = fnames_in_stripped;
        classifier_struct.model_description      = model_description;
        classifier_struct.AUROCs                 = AUROCs;
        classifier_struct.model_validation_stats = model_validation_stats;

        % store the p( IOU > 5 | est_IOU )?
        
        
        
    %% save the model
        
        iter = 0;
        if ~exist(saved_models_directory,'dir'), mkdir( saved_models_directory ); end
        saved_model_fname = fullfile( saved_models_directory, [ [classes{:}] ', ' model_description ', ' num2str(iter) '.mat'] );
        while exist(saved_model_fname,'file')
            iter = iter + 1;
            saved_model_fname = fullfile( saved_models_directory, [ [classes{:}] ', ' model_description ', ' num2str(iter) '.mat'] );
        end
        save(saved_model_fname,'-struct','classifier_struct');
        display(['saved ' model_description ' model to: ' saved_model_fname ]);

        
        
end
    
    
    
            
        
        
        