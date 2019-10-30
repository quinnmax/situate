function [boxes_r0rfc0cf_return, class_assignments_return, confidences_return, cnn_features_return, total_cnn_calls] = rcnn_homebrew( im, box_area_ratios, box_aspect_ratios, box_overlap_ratio, varargin )
% [boxes_r0rfc0cf, class_assignments, confidences, cnn_features, total_cnn_calls] = rcnn_homebrew( im, box_area_ratios, box_aspect_ratios, overlap_ratio, classifier_model, box_adjust_model, [use_non_max_suppression],[num_box_adjust_iterations], [show_viz], [show_progress] ); );
%
% defaults for:
%   box_area_ratios   : [1/16 1/9 1/4]
%   box_aspect_ratios : [1/2 1/1 2/1]
%   box_overlap_ratio : .5
%   use_non_max_suppression : true
%   show_viz                : false
%   show_progress           : true
%
% to try to pick an existing model:
% [boxes_r0rfc0cf, class_assignments, confidences, cnn_features] = rcnn_homebrew( im, box_area_ratios, box_aspect_ratios, overlap_ratio, training_fnames, situation_description, [use_non_max_suppression], [show_viz], [show_progress] );
% [boxes_r0rfc0cf, class_assignments, confidences, cnn_features] = rcnn_homebrew( im, box_area_ratios, box_aspect_ratios, overlap_ratio, training_fnames, situation_struct,      [use_non_max_suppression], [show_viz], [show_progress] );
%
%     classifier_model = 
%         struct with fields:
%             models: {3×1 cell}
%             classes: {'dogwalker'  'dog'  'leash'}
%     classifier_model.models
%         3×1 cell array (obj index)
%             [4097×1 double]
%             [4097×1 double]
%             [4097×1 double]
%
%     box_adjust_model = 
%         struct with fields:
%             object_types: {'dogwalker'  'dog'  'leash'}
%             feature_descriptions: {'delta x in widths'  'delta y in heights'  'log w ratio'  'log h ratio'}
%             weight_vectors: {3×4 cell}
%     box_adjust_model.weight_vectors
%         3×4 cell array (obj index, adjustment type)
%             [4097×1 double]    [4097×1 double]    [4097×1 double]    [4097×1 double]
%             [4097×1 double]    [4097×1 double]    [4097×1 double]    [4097×1 double]
%             [4097×1 double]    [4097×1 double]    [4097×1 double]    [4097×1 double]

    
    
    
    
    
    

%% process inputs
    
        if isempty( box_area_ratios )
            box_area_ratios = [1/16 1/9 1/4];
        end

        if isempty( box_aspect_ratios )
            box_aspect_ratios = [1/2 1/1 2/1];
        end

        if isempty( box_overlap_ratio )
            box_overlap_ratio = .5;
        end
   
    % figure out first two parts of varargin
    % need to end up with classification functions and box-adjust functions
    if iscellstr(varargin{1})
        
        % need to load classifiers given training data

        training_fnames = varargin{1};
        if isstruct( varargin{2} )
            situation_struct = varargin{2};
        elseif ischar(varargin{2} )
            situation_struct = situate.situation_struct_load_all( varargin{2} );
        else
            error('given training images, need situation_description or situation_model');
        end

        classifier_model = classifiers.IOU_ridge_regression_train( situation_struct, training_fnames, 'saved_models/' );
        box_adjust_model = agent_adjustment.bb_regression_train( situation_struct, training_fnames, 'saved_models/', .6 );
     
    elseif isstruct(varargin{1}) && isstruct(varargin{2})
        classifier_model = varargin{1};
        box_adjust_model = varargin{2};
    else 
        error('inputs don''t match expected formats');
    end
    
    if numel(varargin) >= 3 && ~isempty(varargin{3})
        use_non_max_suppression = varargin{3};
    else
        use_non_max_suppression = true;
    end
    
    if numel(varargin) >= 4  && ~isempty(varargin{4})
        num_box_adjust_iterations = varargin{4};
    else
        num_box_adjust_iterations = 1;
    end
    
    
    if numel(varargin) >= 5  && ~isempty(varargin{5})
        show_viz = varargin{5};
    else
        show_viz = false;
    end
    
    if numel(varargin) >= 6  && ~isempty(varargin{6})
        show_progress = varargin{6};
    else
        show_progress = false;
    end
    
   
    situation_objects = classifier_model.classes;
    num_objs = length(situation_objects);
    
    total_cnn_calls = 0;
    
%% get boxes, get cnn features, get scores, do suppression

    % get boxes
    boxes_r0rfc0cf = boxes_covering( size(im), box_aspect_ratios, box_area_ratios, box_overlap_ratio );
    num_boxes = size(boxes_r0rfc0cf,1);
    
    % grab cnn features
    cnn_features = [];
    for bi = num_boxes:-1:1
        r0 = boxes_r0rfc0cf(bi,1);
        rf = boxes_r0rfc0cf(bi,2);
        c0 = boxes_r0rfc0cf(bi,3);
        cf = boxes_r0rfc0cf(bi,4);

        cnn_features(bi,:) = cnn.cnn_process( im(r0:rf,c0:cf,:) );
        if show_progress
            progress(num_boxes-bi+1,size(boxes_r0rfc0cf,1),'rcnn: extracting cnn features from anchor boxes: ' );
        end
    end
    total_cnn_calls = total_cnn_calls + num_boxes;
    
    % score boxes
    classification_score_matrix = padarray(cnn_features,[0,1],1,'pre') * horzcat(classifier_model.models{:});
    
    % apply non-max suppression
    if use_non_max_suppression
        for oi = 1:num_objs
            iou_suppression_threshold = .5;
            inds_suppress = non_max_supression( boxes_r0rfc0cf, classification_score_matrix(:,oi), iou_suppression_threshold, 'r0rfc0cf' );
            classification_score_matrix( inds_suppress, oi ) = 0;
        end
    end
    
    classification_score_matrix(classification_score_matrix < .05) = 0;
    class_assignments_initial = classification_score_matrix > 0;
    
    % remove junk
    inds_remove = ~any( class_assignments_initial,2);
    class_assignments_initial(inds_remove,:) = [];
    classification_score_matrix(inds_remove,:) = [];
    boxes_r0rfc0cf(inds_remove,:) = [];
    cnn_features(inds_remove,:) = [];
    
    
%% get adjusted boxes, get updated scores
    
    [boxes_new_r0rfc0cf, cnn_features_new] = generate_new_boxes( boxes_r0rfc0cf, cnn_features, classification_score_matrix, box_adjust_model, im );
    total_cnn_calls = total_cnn_calls + size(boxes_new_r0rfc0cf,1);
    
    % get updated scores
    classification_score_matrix_new = padarray(cnn_features_new,[0,1],1,'pre') * horzcat(classifier_model.models{:});
    
    % remove junk rows
    inds_remove = all( classification_score_matrix_new < .05, 2 );
    classification_score_matrix_new(inds_remove,:) = [];
    boxes_new_r0rfc0cf(inds_remove,:) = [];
    cnn_features_new(inds_remove,:) = [];
    
    
    
    
%% combine and re-supress
    
    % combine original boxes and adjusted boxes
    boxes_combined_r0rfc0cf = [boxes_r0rfc0cf; boxes_new_r0rfc0cf];
    classification_score_matrix_combined = [classification_score_matrix; classification_score_matrix_new];
    cnn_features_combined = [cnn_features; cnn_features_new];
    
    % apply non-max suppression
    if use_non_max_suppression
        for oi = 1:num_objs
            iou_suppression_threshold = .5;
            inds_suppress = non_max_supression( boxes_combined_r0rfc0cf, classification_score_matrix_combined(:,oi), iou_suppression_threshold, 'r0rfc0cf' );
            classification_score_matrix_combined( inds_suppress, oi ) = 0;
            
        end
    end
    
    % remove junk
    classification_score_matrix_combined(classification_score_matrix_combined < .05) = 0;
    rows_remove = ~any(classification_score_matrix_combined,2);
    boxes_combined_r0rfc0cf(rows_remove,:) = [];
    classification_score_matrix_combined(rows_remove,:) = [];
    cnn_features_combined(rows_remove,:) = [];
    
    
%% regenerate, recombine, resupress

for iter = 1:num_box_adjust_iterations

    % winnow
    chopping_block = nan(size(classification_score_matrix_combined));
    for oi = 1:num_objs
        cur_scores = sort(classification_score_matrix_combined(:,oi),'descend');
        cutoff = min(10,size(classification_score_matrix_combined,1));
        chopping_block(:,oi) = classification_score_matrix_combined(:,oi) < cur_scores(cutoff);
    end
    rows_remove = all(chopping_block,2);
    boxes_combined_r0rfc0cf(rows_remove,:) = [];
    classification_score_matrix_combined(rows_remove,:) = [];
    cnn_features_combined(rows_remove,:) = [];
    
    

    [boxes_newer_r0rfc0cf, cnn_features_newer] = generate_new_boxes( boxes_combined_r0rfc0cf, cnn_features_combined, classification_score_matrix_combined, box_adjust_model, im );
    total_cnn_calls = total_cnn_calls + size(boxes_newer_r0rfc0cf,1);
    
    % get updated scores
    classification_score_matrix_newer = padarray(cnn_features_newer,[0,1],1,'pre') * horzcat(classifier_model.models{:});
    
    % remove junk rows
    inds_remove = all( classification_score_matrix_newer < .05, 2 );
    classification_score_matrix_newer(inds_remove,:) = [];
    boxes_newer_r0rfc0cf(inds_remove,:) = [];
    cnn_features_newer(inds_remove,:) = [];
    
    % combine original boxes and adjusted boxes
    boxes_combined_r0rfc0cf = [boxes_combined_r0rfc0cf; boxes_newer_r0rfc0cf];
    classification_score_matrix_combined = [classification_score_matrix_combined; classification_score_matrix_newer];
    cnn_features_combined = [cnn_features_combined; cnn_features_newer];
   
    % apply non-max suppression
    if use_non_max_suppression
        for oi = 1:num_objs
            iou_suppression_threshold = .5;
            inds_suppress = non_max_supression( boxes_combined_r0rfc0cf, classification_score_matrix_combined(:,oi), iou_suppression_threshold, 'r0rfc0cf' );
            classification_score_matrix_combined( inds_suppress, oi ) = 0;
            
        end
    end
    
    % remove junk
    classification_score_matrix_combined(classification_score_matrix_combined < .05) = 0;
    rows_remove = ~any(classification_score_matrix_combined,2) | isnan(boxes_combined_r0rfc0cf(:,1));
    boxes_combined_r0rfc0cf(rows_remove,:) = [];
    classification_score_matrix_combined(rows_remove,:) = [];
    cnn_features_combined(rows_remove,:) = [];
    
end
    
    %% return vals
    % go ahead and replicate things that are over threshold for multiple categories

    boxes_r0rfc0cf_return    = [];
    class_assignments_return = [];
    confidences_return       = [];
    cnn_features_return      = [];
    for oi = 1:num_objs
        cur_rows  = classification_score_matrix_combined(:,oi) > 0;
        num_boxes = sum(cur_rows);
        class_assignments_return( end+1:end+num_boxes )   = oi;
        boxes_r0rfc0cf_return(    end+1:end+num_boxes, :) = boxes_combined_r0rfc0cf(cur_rows,:);
        confidences_return(       end+1:end+num_boxes )   = classification_score_matrix_combined(cur_rows,oi);
        cnn_features_return(      end+1:end+num_boxes, :) = cnn_features_combined(cur_rows,:);
    end
    
    
    %% visualize
    if show_viz
    max_boxes_per_obj = 5;
    figure
    for oi = 1:num_objs
      
        % show the best initial boxes
        cur_rows = class_assignments_initial(:,oi);
        temp_scores = cur_rows .* classification_score_matrix(:,oi);
        [~,sort_order] = sort(temp_scores,'descend');
        n = min( max_boxes_per_obj, sum( temp_scores > 0 ) );
        
        subplot2(2,num_objs,1,oi);
        imshow(im);
        hold on; 
        draw_box( boxes_r0rfc0cf( sort_order(1:n), : ), 'r0rfc0cf' );
        hold off
        ylabel('top scoring original boxes');
        title(situation_objects{oi});
        
        
        
        % show the post-adjustment boxes
        cur_rows = eq(class_assignments_return,oi);
        temp_scores = cur_rows .* confidences_return;
        [~,sort_order_post] = sort( temp_scores, 'descend');
        n = min( max_boxes_per_obj, sum( temp_scores > 0 ) );
        
        subplot2(2,num_objs,2,oi);
        imshow(im);
        hold on; 
        draw_box( boxes_r0rfc0cf_return( sort_order_post(1:n), : ), 'r0rfc0cf' );
        hold off
        ylabel('top scoring boxes (original + adjusted)');
        
    end
    end
    
end









function inds_supress = non_max_supression( boxes, box_scores, IOU_suppression_threshold, box_format )
% inds_suppress = non_max_supression( boxes, box_scores, IOU_suppression_threshold, box_format );

    if ~exist('IOU_supression_threshold','var') || isempty(IOU_suppression_threshold)
        IOU_suppression_threshold = .25;
    end

    % want to use 0 as the floor
    box_scores = box_scores - min(box_scores(:));
    box_scores_initial = box_scores;
    
    go_again = true;
    while go_again
        go_again = false;
        for bi = 1:size(boxes,1)
            iou_vect = intersection_over_union( boxes(bi,:), boxes, box_format, box_format );
            overlap_box_inds = iou_vect > IOU_suppression_threshold;
            % if all indesecting boxes have lower scores (or equal)
            if all( box_scores( overlap_box_inds ) <= box_scores(bi) )
                % mark everything but this box for supression
                suppress_inds = setsub( find(overlap_box_inds), bi );
                if any( box_scores( suppress_inds ) ~= 0 )
                    % if we actually do supress something, go again
                    box_scores( suppress_inds ) = 0;
                    go_again = true;
                end

            end
        end
    end
    
    inds_supress = ~eq( box_scores_initial, box_scores );
    
end




function [boxes_new_r0rfc0cf, cnn_features_new] = generate_new_boxes( boxes_r0rfc0cf, cnn_features, classification_score_matrix, box_adjust_model, im )

    % ignore boxes under .05 conf
    class_assignments_initial = (classification_score_matrix > .05);
    num_objs = size(classification_score_matrix,2);
    
    % get box adjust model
    if strcmp( box_adjust_model.model_description, 'box_adjust')
        model_mats = arrayfun( @(oi) [box_adjust_model.weight_vectors{oi,:}], 1:num_objs, 'uniformoutput', false );
    elseif strcmp( box_adjust_model.model_description, 'box_adjust_two_tone')
        model_mats{1} = arrayfun( @(oi) [box_adjust_model.sub_models{1}.weight_vectors{oi,:}], 1:num_objs, 'uniformoutput', false );
        model_mats{2} = arrayfun( @(oi) [box_adjust_model.sub_models{2}.weight_vectors{oi,:}], 1:num_objs, 'uniformoutput', false );
    end
    
 % generate adjusted boxes
    % some boxes are over threshold for more than one object type. 
    % we'll make adjustment boxes for both interpretations.
    boxes_new_r0rfc0cf = nan( sum(class_assignments_initial(:)), 4);
    iter = 1;
    for oi = 1:num_objs
        cur_obj_rows = find(class_assignments_initial(:,oi));
        for bi = cur_obj_rows(1:numel(cur_obj_rows))'
            
            if strcmp( box_adjust_model.model_description, 'box_adjust')
                boxes_new_r0rfc0cf(iter,:) = agent_adjustment.bb_regression_adjust_box( model_mats{oi}, boxes_r0rfc0cf(bi,:), im, cnn_features(bi,:) ); 
            elseif strcmp( box_adjust_model.model_description, 'box_adjust_two_tone')
                cur_conf = classification_score_matrix(bi,oi);
                if cur_conf < box_adjust_model.model_selection_threshold(oi)
                    boxes_new_r0rfc0cf(iter,:) = agent_adjustment.bb_regression_adjust_box( model_mats{1}{oi}, boxes_r0rfc0cf(bi,:), im, cnn_features(bi,:) ); 
                else
                    boxes_new_r0rfc0cf(iter,:) = agent_adjustment.bb_regression_adjust_box( model_mats{2}{oi}, boxes_r0rfc0cf(bi,:), im, cnn_features(bi,:) ); 
                end
            end
            iter = iter + 1;
        end
        
    end
    
    boxes_new_r0rfc0cf( isnan(boxes_new_r0rfc0cf(:,1)), : ) = [];
        
    % get cnn features for post-adjusted boxes
    % this caused a bug when the very last box new was nan. the arrays didn't match in size. 
    cnn_features_new = [];
    for bi = size(boxes_new_r0rfc0cf,1):-1:1
        r0 = boxes_new_r0rfc0cf(bi,1);
        rf = boxes_new_r0rfc0cf(bi,2);
        c0 = boxes_new_r0rfc0cf(bi,3);
        cf = boxes_new_r0rfc0cf(bi,4);
        if ~any(isnan([r0 rf c0 cf]))
            cnn_features_new(bi,:) = cnn.cnn_process( im(r0:rf,c0:cf,:) );
        end
    end
    
end
    
   


   
    
    
 
    
    
    
    
    
    
    
    
    

