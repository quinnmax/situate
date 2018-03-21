
function model = bb_regression_train( situation_struct, fnames_in, saved_models_directory, training_IOU_threshold )

% model = bb_regression_train( situation_struct, fnames_in, saved_models_directory, training_IOU_threshold )
%
% load or train a box_adjust model. currently requires an existing
% cnn_features file that's hard coded in
 
    situation_objects = situation_struct.situation_objects;

    %% check for existing model
    
    fnames_in_stripped = fileparts_mq(fnames_in, 'name');
    
    model_description = 'box_adjust';
    if exist(saved_models_directory,'dir')
        selected_model_fname = situate.check_for_existing_model(...
            saved_models_directory, ...
            'fnames_train',fnames_in_stripped,...
            'model_description',model_description, ...
            'object_types', situation_objects, ...
            'IOU_threshold', training_IOU_threshold);
    else
        selected_model_fname =[];
    end
    
    if ~isempty(selected_model_fname)
        model = load(selected_model_fname);
        display(['loaded ' model_description ' model from: ' selected_model_fname ]);
        return;
    end
    
    %% load or generate crops
    
    existing_feature_directory = 'pre_extracted_feature_data';
    selected_datafile_fname = situate.check_for_existing_model( ...
        existing_feature_directory, 'object_labels', sort(situation_objects) );
   
    if ~isempty(selected_datafile_fname)
        display(['loading cnn feature data from: ' selected_datafile_fname]);
        existing_features_fname = selected_datafile_fname;
    else
        disp('extracting cnn feature data');
        existing_features_fname = cnn.feature_extractor_bulk( [], existing_feature_directory, situation_struct );
    end
    
    data = load(existing_features_fname);
    
    %% build model
    
    model_description = 'box_adjust';
    
    model = [];
    model.model_description = model_description;
    model.object_types = situation_objects;
    model.fnames_train = fnames_in;
    model.IOU_threshold = training_IOU_threshold;
    model.feature_descriptions = {'delta x in widths','delta y in heights','log w ratio','log h ratio'};
    model.weight_vectors = cell( length(model.object_types), length(model.feature_descriptions) );
    
    fnames_file_stripped = fileparts_mq(data.fnames, 'name' );
    fnames_in_stripped   = fileparts_mq(fnames_in, 'name' );
    
    fnames_train_inds = find(ismember( fnames_file_stripped, fnames_in_stripped ));
    rows_train = ismember( data.fname_source_index, fnames_train_inds );
    
    % when there are multiple objects of the same type in the current box
    % we want to train the regressor to move to the object that it has the highest current IOU with.
    % this means identifying when the source box is lower IOU than another box for an object of the
    % same type.
    
    % situation objects of same type
    object_equivalence_matrix = false(length(situation_objects),length(situation_objects));
    for oi = 1:length(situation_objects)
    for oj = 1:length(situation_objects)
        object_equivalence_matrix(oi,oj) = isequal( sort(situation_struct.situation_objects_possible_labels{oi}), sort(situation_struct.situation_objects_possible_labels{oj}) );
    end
    end
    
    object_confusion_rows = false( size(data.IOUs_with_source) );
    for oi = 1:length(situation_objects)
        object_confusion_rows = ...
            object_confusion_rows | ...
            data.IOUs_with_source < max( data.IOUs_with_each_gt_obj(:,object_equivalence_matrix(oi,:)), [], 2 );
    end
    
    boxes_over_IOU_threshold_inds = ge( data.IOUs_with_source, training_IOU_threshold );
    
    lambda = 1000; % ridge regression parameter
    
    display('box_adjust model training');
    for oi = 1:length(model.object_types)
        cur_box_rows = ...
            eq( oi, data.box_source_obj_type ) ...
            & rows_train ...
            & boxes_over_IOU_threshold_inds...
            & ~object_confusion_rows;
        for fi = 1:length(model.feature_descriptions) % delta x, delta y, delta w, delta h
            model.weight_vectors{oi,fi} = ridge( data.box_deltas_xywh(cur_box_rows,fi), data.box_proposal_cnn_features(cur_box_rows,:), lambda, 0);
            fprintf('.');
        end
        fprintf('\n');
    end
    
    
    
    
    
    % get results on training data
    
    adjustment_results_training = cell(1, length(situation_objects) ); % proposed box IOU and adjusted box IOU
    
    for oi = 1:length(situation_objects)

        obj_inds = eq( data.box_source_obj_type,oi);
        cur_inds = rows_train & obj_inds;
        
        % get starting stats
        proposed_box_IOUs = data.IOUs_with_source( cur_inds );
        source_boxes_r0rfc0cf = data.box_sources_r0rfc0cf( cur_inds,:);
        r0 = data.box_proposals_r0rfc0cf(cur_inds,1);
        rf = data.box_proposals_r0rfc0cf(cur_inds,2);
        c0 = data.box_proposals_r0rfc0cf(cur_inds,3);
        cf = data.box_proposals_r0rfc0cf(cur_inds,4);
        w  = cf - c0 + 1;
        h  =  rf - r0 + 1;
        x  = c0 + w/2 - .5;
        y  = r0 + h/2 - .5;

        % cur cnn features
        cnn_features = data.box_proposal_cnn_features(cur_inds,:);

        % predict the deltas
        delta_x = [ones(size(cnn_features,1),1) cnn_features] * model.weight_vectors{oi,1};
        delta_y = [ones(size(cnn_features,1),1) cnn_features] * model.weight_vectors{oi,2};
        delta_w = [ones(size(cnn_features,1),1) cnn_features] * model.weight_vectors{oi,3};
        delta_h = [ones(size(cnn_features,1),1) cnn_features] * model.weight_vectors{oi,4};

        % predict the new box values
        adjusted_x = x  + delta_x .* w;
        adjusted_y = y  + delta_y .* h;
        adjusted_w = w .* exp(delta_w);
        adjusted_h = h .* exp(delta_h);

        r0_adjusted = round( adjusted_y  - adjusted_h/2 +.5 );
        rf_adjusted = round( r0_adjusted + adjusted_h - 1);
        c0_adjusted = round( adjusted_x  - adjusted_w/2 +.5);
        cf_adjusted = round( c0_adjusted + adjusted_w - 1);

        box_adjusted_r0rfc0cf = [ r0_adjusted rf_adjusted c0_adjusted cf_adjusted ];

        % get updated IOUs with original source
        adjusted_box_IOUs = -1 * ones( size(box_adjusted_r0rfc0cf,1), 1 );
        for bi = 1:length(adjusted_box_IOUs)
            adjusted_box_IOUs(bi) = intersection_over_union( box_adjusted_r0rfc0cf(bi,:), source_boxes_r0rfc0cf(bi,:), 'r0rfc0cf');
        end
        adjustment_results_training{oi}.proposed_box_IOUs = proposed_box_IOUs;
        adjustment_results_training{oi}.adjusted_box_IOUs = adjusted_box_IOUs;
    
        iou_improvement = adjusted_box_IOUs - proposed_box_IOUs;
        
        % expected improvement
        n = 40;
        bin_centers = linspace(0,1,n);
        bin_width = 1/(n/2); % some smoothig
        
        adjustment_results_training{oi}.improvement_bin_centers = bin_centers;
        adjustment_results_training{oi}.improvement_mean = zeros(1,length(bin_centers)-1);
        adjustment_results_training{oi}.improvement_std  = zeros(1,length(bin_centers)-1);
        for ni = 1:n
            bin_left  = bin_centers(ni) - bin_width/2;
            bin_right = bin_centers(ni) + bin_width/2;
            cur_inds = (bin_left <= proposed_box_IOUs) & (proposed_box_IOUs < bin_right );
            adjustment_results_training{oi}.improvement_mean(ni) = mean( iou_improvement( cur_inds ) );
            adjustment_results_training{oi}.improvement_std(ni)  = std(  iou_improvement( cur_inds ) );
        end
        
    end
    
    model.adjustment_results_training = adjustment_results_training;
    
    
    
    % save the model
    
    iter = 0;
    if ~exist(saved_models_directory,'dir'), mkdir(saved_models_directory); end
    saved_model_fname = fullfile( saved_models_directory, [ [situation_objects{:}] ', ' model_description ', ' num2str(iter) '.mat'] );
    while exist(saved_model_fname,'file')
        iter = iter + 1;
        saved_model_fname = fullfile( saved_models_directory, [ [situation_objects{:}] ', ' model_description ', ' num2str(iter) '.mat'] );
    end
    save(saved_model_fname,'-struct','model');
    display(['saved ' model_description ' model to: ' saved_model_fname ]);
    
    
    
    % show results for training data
    
    show_results_on_training_data = true;
    if show_results_on_training_data
    
        figure;
        for oi = 1:length(situation_objects)
            
            subplot(1,length(situation_objects),oi);
            plot( adjustment_results_training{oi}.proposed_box_IOUs, adjustment_results_training{oi}.adjusted_box_IOUs, '.');
            xlabel('proposed box IOU');
            ylabel('adjusted box IOU');
            title(situation_objects{oi});
            hold on;
            plot([0 1],[0 1],'r');
            
        end
        
        figure
        for oi = 1:length(situation_objects)
            subplot(1,length(situation_objects),oi);
            plot( adjustment_results_training{oi}.improvement_bin_centers, adjustment_results_training{oi}.improvement_mean, 'blue' );
            hold on;
            plot( adjustment_results_training{oi}.improvement_bin_centers, adjustment_results_training{oi}.improvement_mean + adjustment_results_training{oi}.improvement_std, 'red' )
            plot( adjustment_results_training{oi}.improvement_bin_centers, adjustment_results_training{oi}.improvement_mean - adjustment_results_training{oi}.improvement_std, 'red' )
            ylim([-.3 .6]);
            plot([0 1],[0 0],'--k');
        end
        
    end
    
  
        
    
end
    
    
    

    