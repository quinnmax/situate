function [boxes_r0rfc0cf_return, class_assignments_return, confidences_return, cnn_features_return] = rcnn_homebrew( im, box_area_ratios, box_aspect_ratios, box_overlap_ratio, varargin )
% [boxes_r0rfc0cf, class_assignments, confidences, cnn_features] = rcnn_homebrew( im, box_area_ratios, box_aspect_ratios, overlap_ratio, classifier_model, box_adjust_model, [use_non_max_suppression], [show_viz] ); );
%
% defaults for:
%   box_area_ratios   : [1/16 1/9 1/4]
%   box_aspect_ratios : [1/2 1/1 2/1]
%   box_overlap_ratio : .5
%   use_non_max_suppression : true
%   show_viz                : false
%
% to try to pick an existing model:
% [boxes_r0rfc0cf, class_assignments, confidences, cnn_features] = rcnn_homebrew( im, box_area_ratios, box_aspect_ratios, overlap_ratio, training_fnames, situation_description, [use_non_max_suppression], [show_viz] );
% [boxes_r0rfc0cf, class_assignments, confidences, cnn_features] = rcnn_homebrew( im, box_area_ratios, box_aspect_ratios, overlap_ratio, training_fnames, situation_struct,      [use_non_max_suppression], [show_viz] );
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
    
    if numel(varargin) >= 3
        use_non_max_suppression = varargin{3};
    else
        use_non_max_suppression = true;
    end
    
    if numel(varargin) >= 4
        show_viz = varargin{4};
    else
        show_viz = false;
    end
    
    situation_objects = classifier_model.classes;
    num_objs = length(situation_objects);
    
    
   
    
    
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
        progress(num_boxes-bi+1,size(boxes_r0rfc0cf,1));
    end
    
    % score boxes
    classification_score_matrix = padarray(cnn_features,[0,1],1,'pre') * horzcat(classifier_model.models{:});
    [estimated_iou,class_assignments] = max(classification_score_matrix,[],2);
    
    % apply non-max suppression
    if use_non_max_suppression
        for oi = 1:num_objs
            temp_scores = eq( oi, class_assignments ) .* estimated_iou;
            temp_scores( temp_scores < 0 ) = 0;
            iou_suppression_threshold = .5;
            inds_suppress = non_max_supression( boxes_r0rfc0cf, temp_scores, iou_suppression_threshold, 'r0rfc0cf' );
            estimated_iou( inds_suppress ) = 0;
        end
        % cull
        rows_cull = estimated_iou < .05;
        boxes_r0rfc0cf( rows_cull, : ) = [];
        cnn_features( rows_cull, : )   = [];
        estimated_iou( rows_cull )     = [];
        class_assignments( rows_cull ) = [];
        num_boxes = size(boxes_r0rfc0cf,1);
    end
    
%% get adjusted boxes, get updated scores, suppress
        
    % get adjusted boxes
    box_adjust_mats = cell(1,num_objs);
    boxes_adjusted_r0rfc0cf = nan(num_boxes,4);
    
        % build a single mat for adjusting each obj type
        for oi = 1:length(situation_objects)
            box_adjust_mats{oi} = cell2mat(box_adjust_model.weight_vectors(oi,:));
        end
    
        % apply box adjust
        for bi = 1:num_boxes
            boxes_adjusted_r0rfc0cf(bi,:) = agent_adjustment.bb_regression_adjust_box( box_adjust_mats{class_assignments(bi)}, boxes_r0rfc0cf(bi,:), im, cnn_features(bi,:) );
        end
      
    % get cnn features for post-adjusted boxes
    cnn_features_post = nan( num_boxes, size( cnn_features,2 ) );
    for bi = 1:num_boxes
        r0 = boxes_adjusted_r0rfc0cf(bi,1);
        rf = boxes_adjusted_r0rfc0cf(bi,2);
        c0 = boxes_adjusted_r0rfc0cf(bi,3);
        cf = boxes_adjusted_r0rfc0cf(bi,4);
        if ~any(isnan([r0 rf c0 cf]))
            cnn_features_post(bi,:) = cnn.cnn_process( im(r0:rf,c0:cf,:) );
        end
        progress(bi,num_boxes);
    end
  
    % get updated scores
    classification_score_matrix_post = padarray(cnn_features_post,[0,1],1,'pre') * horzcat(classifier_model.models{:});
    estimated_iou_post = nan(size(estimated_iou));
    for bi = 1:num_boxes
        estimated_iou_post(bi) = classification_score_matrix_post(bi, class_assignments(bi) );
    end
    class_assignments_post = class_assignments;
    
    % apply non max suppression again
    if use_non_max_suppression
    for oi = 1:num_objs
        temp_scores = estimated_iou_post .* eq( oi, class_assignments_post );
        temp_scores( temp_scores < 0 ) = 0;
        iou_suppression_threshold = .5;
        inds_suppress = non_max_supression( boxes_adjusted_r0rfc0cf, temp_scores, iou_suppression_threshold, 'r0rfc0cf' );
        estimated_iou_post( inds_suppress ) = 0;
    end
    
    % cull
    rows_cull = estimated_iou_post < .05 | isnan(estimated_iou_post);
    boxes_adjusted_r0rfc0cf( rows_cull, : ) = [];
    cnn_features_post( rows_cull, : )   = [];
    estimated_iou_post( rows_cull )     = [];
    class_assignments_post( rows_cull ) = [];
    num_boxes_post = size(boxes_adjusted_r0rfc0cf,1);
    end
    
    %% return vals
    
    boxes_r0rfc0cf_return = boxes_adjusted_r0rfc0cf;
    class_assignments_return = class_assignments_post;
    confidences_return = estimated_iou_post;
    cnn_features_return = cnn_features_post;
    
    %%
    
    % visualize
    if show_viz
    max_boxes_per_obj = 4;
    figure
    for oi = 1:num_objs
        
        cur_rows = eq(class_assignments,oi);
        temp_scores = cur_rows .* estimated_iou;
        [~,sort_order] = sort( temp_scores, 'descend');
        n = min( max_boxes_per_obj, sum( temp_scores > 0 ) );
        
        subplot2(3,num_objs,1,oi);
        imshow(im);
        hold on; 
        draw_box( boxes_r0rfc0cf( sort_order(1:n), : ), 'r0rfc0cf' );
        hold off
        title( situation_objects{oi});
        ylabel('top n scoring boxes from initial pool');
        
        subplot2(3,num_objs,2,oi);
        imshow(im);
        hold on; 
        draw_box( boxes_adjusted_r0rfc0cf( sort_order(1:n), : ), 'r0rfc0cf' );
        hold off
        ylabel('adjusted boxes of those original top n');
        
        cur_rows = eq(class_assignments_post,oi);
        temp_scores = cur_rows .* estimated_iou_post;
        %temp_score = cur_rows .* ( .8*estimated_iou_post + .2*estimated_iou);
        [~,sort_order_post] = sort( temp_scores, 'descend');
        n = min( max_boxes_per_obj, sum( temp_scores > 0 ) );
        
        subplot2(3,num_objs,3,oi);
        imshow(im);
        hold on; 
        draw_box( boxes_adjusted_r0rfc0cf( sort_order_post(1:n), : ), 'r0rfc0cf' );
        hold off
        ylabel('top scoring adjusted boxes');
        
    end
    end
   
    
    
 
    
    
    
    
    
    
    
    
    

