
function model = train( p, fnames_in, saved_models_directory, training_IOU_threshold )

% model = train( p, fnames_in, saved_models_directory, training_IOU_threshold );
%
% load or train a box_adjust model. currently requires an existing
% cnn_features file that's hard coded in
 
    if ~exist('training_IOU_threshold','var') || isempty(training_IOU_threshold)
        error('need a training IOU threshold');
        training_IOU_threshold = .1;
    end
    if ~exist('fnames_in','var') || isempty(fnames_in)
        error('need the fnames in');
        fnames_in = data.fnames(1:400);
        warning('box_adjust.train using default data');
    end
    if ~exist('p','var') || isempty(p)
        error('need a situate parameters structure');
        p = data.p;
        warning('box_adjust.train using default data');
    end

    
    % see if we can find a model that exists with the same training files and parameterization
    
    fnames_in_pathless = cellfun( @(x) x( last(strfind(x,filesep()))+1:end), fnames_in, 'UniformOutput', false );
    
    model_description = 'box_adjust';
    model_fname = situate.check_for_existing_model(...
        {saved_models_directory,'default_models'}, ...
        'fnames_train',fnames_in_pathless,...
        'model_description',model_description, ...
        'object_types', p.situation_objects);
    
    if ~isempty(model_fname)
        model = load(model_fname);
        display(['box_adjust model loaded from ' model_fname]);
        return;
    end
    
    % if not found, build it
    
    tic;
    
    existing_feature_directory = 'pre_extracted_feature_data';
    selected_datafile_fname = situate.check_for_existing_model( ...
        existing_feature_directory, 'object_labels', sort(p.situation_objects) );
    if ~isempty(selected_datafile_fname)
        display(['loaded cnn feature data from ' selected_datafile_fname]);
        existing_features_fname = selected_datafile_fname;
    else
        display('extracting cnn feature data');
        existing_features_fname = cnn_feature_extractor( fileparts(fnames_in{1}), existing_feature_directory, p );
    end    
    
    if ~isempty(selected_datafile_fname)
        existing_features_fname = selected_datafile_fname;
    else
        existing_features_fname = cnn_feature_extractor( [], existing_feature_directory, p );
    end
    data = load(existing_features_fname);
    
    model_description = 'box_adjust';
    
    model = [];
    model.model_description = model_description;
    model.object_types = p.situation_objects;
    model.fnames_train = fnames_in;
    model.IOU_threshold = training_IOU_threshold;
    model.feature_descriptions = {'delta x in widths','delta y in heights','log w ratio','log h ratio'};
    model.weight_vectors = cell( length(model.object_types), length(model.feature_descriptions) );
    
    fnames_file_pathless = cellfun( @(x) x(last(strfind(x,filesep()))+1:end), data.fnames, 'UniformOutput',false);
    fnames_in_pathless = cellfun( @(x) x(last(strfind(x,filesep()))+1:end), fnames_in, 'UniformOutput',false);
    fnames_train_inds = find(ismember( fnames_file_pathless, fnames_in_pathless ));
    training_box_inds = ismember( data.fname_source_index, fnames_train_inds );
    
    boxes_over_IOU_threshold_inds = ge( data.IOUs_with_source, training_IOU_threshold );
    
    lambda = 1000; % ridge regression parameter
    
    display('box_adjust model training');
    for oi = 1:length(model.object_types)
        cur_box_rows = eq( oi, data.box_source_obj_type ) & training_box_inds & boxes_over_IOU_threshold_inds;
        for fi = 1:length(model.feature_descriptions) % delta x, delta y, delta w, delta h
            model.weight_vectors{oi,fi} = ridge( data.box_deltas_xywh(cur_box_rows,fi), data.box_proposal_cnn_features(cur_box_rows,:), lambda, 0);
            fprintf('.');
        end
        fprintf('\n');
    end
    
    
    % save the model
    
    iter = 0;
    saved_model_fname = fullfile( saved_models_directory, [ [p.situation_objects{:}] ', ' model_description ', ' num2str(iter) '.mat'] );
    while exist(saved_model_fname,'file')
        iter = iter + 1;
        saved_model_fname = fullfile( saved_models_directory, [ [p.situation_objects{:}] ', ' model_description ', ' num2str(iter) '.mat'] );
    end
    save(saved_model_fname,'-struct','model');
    display(['saved ' model_description ' model to: ' saved_model_fname ]);
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    show_results_on_training_data = false;
    if show_results_on_training_data
    
        figure;
        adjustment_results = cell( length(p.situation_objects), 2 ); % proposed box IOU and adjusted box IOU
        for oi = 1:length(p.situation_objects)
        
            max_inds_to_show = 5000;
            obj_inds = eq( data.box_source_obj_type,oi);
            inds_show = ~training_box_inds & obj_inds;
            inds_show_temp = find( inds_show );
            inds_show_temp = inds_show_temp( randperm(length(inds_show_temp),min(max_inds_to_show,length(inds_show_temp)) ) );
            inds_show_temp = sort(inds_show_temp);
            inds_show(:) = false;
            inds_show(inds_show_temp) = true;

            
            % get starting stats
            proposed_box_IOUs = data.IOUs_with_source( inds_show );
            source_boxes_r0rfc0cf = data.box_sources_r0rfc0cf( inds_show,:);
            r0 = data.box_proposals_r0rfc0cf(inds_show,1);
            rf = data.box_proposals_r0rfc0cf(inds_show,2);
            c0 = data.box_proposals_r0rfc0cf(inds_show,3);
            cf = data.box_proposals_r0rfc0cf(inds_show,4);
            w = cf - c0 + 1;
            h = rf - r0 + 1;
            x = c0 + w/2 - .5;
            y = r0 + h/2 - .5;

            % get cnn features, if necessary
            cnn_features = data.box_proposal_cnn_features(inds_show,:);

            % predict the deltas
            delta_x = [ones(size(cnn_features,1),1) cnn_features] * model.weight_vectors{oi,1};
            delta_y = [ones(size(cnn_features,1),1) cnn_features] * model.weight_vectors{oi,2};
            delta_w = [ones(size(cnn_features,1),1) cnn_features] * model.weight_vectors{oi,3};
            delta_h = [ones(size(cnn_features,1),1) cnn_features] * model.weight_vectors{oi,4};

%             % asside, check out the predicted deltas vs the true deltas
%             figure
%             subplot(1,4,1); plot( delta_x, data.box_deltas_xywh(inds_show,1), '.'); hold on; plot([-1 1],[-1 1],'r'); hold off; axis('equal');
%             subplot(1,4,2); plot( delta_y, data.box_deltas_xywh(inds_show,2), '.'); hold on; plot([-1 1],[-1 1],'r'); hold off; axis('equal');
%             subplot(1,4,3); plot( delta_w, data.box_deltas_xywh(inds_show,3), '.'); hold on; plot([-1 1],[-1 1],'r'); hold off; axis('equal');
%             subplot(1,4,4); plot( delta_h, data.box_deltas_xywh(inds_show,4), '.'); hold on; plot([-1 1],[-1 1],'r'); hold off; axis('equal');
            
            % predict the new box values
            adjusted_x = x  + delta_x .* w;
            adjusted_y = y  + delta_y .* h;
            adjusted_w = w .* exp(delta_w);
            adjusted_h = h .* exp(delta_h);

            r0_adjusted = round( adjusted_y  - adjusted_h/2 +.5 );
            rf_adjusted = round( r0_adjusted + adjusted_h - 1);
            c0_adjusted = round( adjusted_x  - adjusted_w/2 +.5);
            cf_adjusted = round( c0_adjusted + adjusted_w - 1);
            
%             % asside, check out the actual coordinates
%             figure
%             subplot(1,4,1); plot( r0_adjusted, source_boxes_r0rfc0cf(:,1), '.'); hold on; plot([0 800],[0 800],'r'); hold off; axis('equal');
%             subplot(1,4,2); plot( rf_adjusted, source_boxes_r0rfc0cf(:,2), '.'); hold on; plot([0 800],[0 800],'r'); hold off; axis('equal');
%             subplot(1,4,3); plot( c0_adjusted, source_boxes_r0rfc0cf(:,3), '.'); hold on; plot([0 800],[0 800],'r'); hold off; axis('equal');
%             subplot(1,4,4); plot( cf_adjusted, source_boxes_r0rfc0cf(:,4), '.'); hold on; plot([0 800],[0 800],'r'); hold off; axis('equal');
           

            box_adjusted_r0rfc0cf = [ r0_adjusted rf_adjusted c0_adjusted cf_adjusted ];

            % get updated IOUs with original source
            adjusted_box_IOUs = -1 * ones( size(box_adjusted_r0rfc0cf,1), 1 );
            for bi = 1:length(adjusted_IOUs)
                adjusted_box_IOUs(bi) = intersection_over_union( box_adjusted_r0rfc0cf(bi,:), source_boxes_r0rfc0cf(bi,:), 'r0rfc0cf');
            end
            adjustment_results{oi,1} = proposed_box_IOUs;
            adjustment_results{oi,2} = adjusted_box_IOUs;
            
            subplot(1,length(p.situation_objects),oi);
            plot( proposed_box_IOUs,adjusted_box_IOUs, '.');
            xlabel('proposed box IOU');
            ylabel('adjusted box IOU');
            title(p.situation_objects{oi});
            hold on;
            plot([0 1],[0 1],'r');
        
        
        
    end
    
    
    
    
end
    
    
    

    