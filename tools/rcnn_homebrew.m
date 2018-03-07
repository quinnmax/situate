function [boxes_r0rfc0cf, confidences, cnn_features] = rcnn_homebrew( im, box_area_ratios, box_aspect_ratios, overlap_ratio, varargin )
    % [boxes_r0rfc0cf, confidences, cnn_features] = rcnn_homebrew( im, box_area_ratios, box_aspect_ratios, overlap_ratio, classifier_model, box_adjust_model );
    % [boxes_r0rfc0cf, confidences, cnn_features] = rcnn_homebrew( im, box_area_ratios, box_aspect_ratios, overlap_ratio, training_fnames, situation_description );
    % [boxes_r0rfc0cf, confidences, cnn_features] = rcnn_homebrew( im, box_area_ratios, box_aspect_ratios, overlap_ratio, training_fnames, situation_model_struct );

    %% process inputs
    
    need_to_load_classifiers = false;
    
    debug = true;
    if debug
        im = imread( 'dogwalking4.jpg' );
        box_area_ratios   = [];
        box_aspect_ratios = [];
        overlap_ratio     = [];
        situation_struct = situate.situation_struct_load_all('dogwalking');
        split_data = situate.data_load_splits_from_directory('/Users/Max/Dropbox/Projects/situate/data_splits/dogwalking_validation/');
        training_fnames = split_data(1).fnames_lb_train;
        need_to_load_classifiers = true;
    end
    
    if isempty( box_area_ratios )
        box_area_ratios = [1/16 1/9 1/4];
    end
    
    if isempty( box_aspect_ratios )
        box_aspect_ratios = [1/2 1/1 2/1];
    end
    
    if isempty( overlap_ratio )
        overlap_ratio = .5;
    end
    
    if ~debug
        if ~isempty(varargin) && iscellstr(varargin{1})

            % then we have training images listed. find a classifier and box adjust model to use

            training_fnames = varargin{1};
            if isstruct( varargin{2} )
                situation_struct = varargin{2};
            elseif ischar(varargin{2} )
                situation_struct = situate.situation_struct_load_all( varargin{2} );
            else
                error('given training images, need situation_description or situation_model');
            end

            need_to_load_classifiers = true;

        elseif isstruct(varargin{1}) && isstruct(varargin{2})
            classifier_model = varargin{1};
            box_adjust_model = varargin{2};
        else 
            error('inputs don''t match expected formats');
        end
    end
    
    if need_to_load_classifiers
        classifier_model = classifiers.IOU_ridge_regression_train( situation_struct, training_fnames, 'saved_models/' );
        box_adjust_model = agent_adjustment.bb_regression_train( situation_struct, training_fnames, 'saved_models/', .1 );
    end
    
    situation_objects = classifier_model.classes;
    num_objs = length(situation_objects);
    
    
    %% generate boxes
    
    boxes_r0rfc0cf = boxes_covering( size(im), box_aspect_ratios, box_area_ratios, overlap_ratio );
    num_boxes = size(boxes_r0rfc0cf,1);
    
    
    %% grab cnn features
    
    cnn_features = [];
    for bi = num_boxes:-1:1
        r0 = boxes_r0rfc0cf(bi,1);
        rf = boxes_r0rfc0cf(bi,2);
        c0 = boxes_r0rfc0cf(bi,3);
        cf = boxes_r0rfc0cf(bi,4);
        cnn_features(bi,:) = cnn.cnn_process( im(r0:rf,c0:cf,:) );
        progress(bi,size(boxes_r0rfc0cf,1));
    end
    
    % classify
    classification_score_matrix = padarray(cnn_features,[0,1],1,'pre') * horzcat(classifier_model.models{:});
    [estimated_iou,class_assignments] = max(classification_score_matrix,[],2);
    
    box_adjust_mats = cell(1,length(situation_struct.situation_objects));
    for oi = 1:length(situation_struct.situation_objects)
        box_adjust_mats{oi} = cell2mat(box_adjust_model.weight_vectors(oi,:));
    end
    
    % apply box adjust
    boxes_adjusted_r0rfc0cf = nan(num_boxes,4);
    for bi = 1:num_boxes
        boxes_adjusted_r0rfc0cf(bi,:) = agent_adjustment.bb_regression_adjust_box( box_adjust_mats{class_assignments(bi)}, boxes_r0rfc0cf(bi,:), im, cnn_features(bi,:) );
        progress(bi,size(boxes_r0rfc0cf,1));
    end
    
    % do non-max suppression
    for oi = 1:num_objs
        cur_rows = eq( oi, class_assignments );
        inds_suppress = non_max_supression( boxes_adjusted_r0rfc0cf(cur_rows,:), estimated_ious(cur_rows), [], 'r0rfc0cf' );
        
    end
    
    
    
    
    
    
    
    
    
    
    
    % visualize resulting boxes
    if visualize
    n = 20;
    figure;
    for oi = 1:num_objs
        cur_boxes = boxes_adjusted_r0rfc0cf( eq(oi,class_assignments), : );
        cur_iou_ests  = estimated_iou( eq(oi,class_assignments) );
        [~,sort_order] = sort(cur_iou_ests,'descend');
        cur_boxes = cur_boxes( sort_order, : );
    
        subplot(1,num_objs,oi);
        imshow(im); 
        hold on;
        draw_box( cur_boxes(1:n,:), 'r0rfc0cf');
        hold off;
        title( situation_objects{oi} );
    end
    end
    
    
    
    % build and show accumulator maps
    if visualize
    accumulator_maps = zeros( size(im,1), size(im,2), num_objs );
    for bi = 1:num_boxes
        r0 = boxes_r0rfc0cf(bi,1);
        rf = boxes_r0rfc0cf(bi,2);
        c0 = boxes_r0rfc0cf(bi,3);
        cf = boxes_r0rfc0cf(bi,4);
    for oi = 1:num_objs
        accumulator_maps(r0:rf,c0:cf,oi) = accumulator_maps(r0:rf,c0:cf,oi) + classification_score_matrix(bi,oi);
    end
    end
    accumulator_maps = mat2gray(accumulator_maps);
    
    figure()
    for oi = 1:num_objs
        subplot2(2,num_objs,1,oi);
        imshow( accumulator_maps(:,:,oi), [] );
        title( situation_objects{oi} );
        
        subplot2(2,num_objs,2,oi);
        imshow( mat2gray(im) + cat(3,accumulator_maps(:,:,oi),zeros(size(im,1),size(im,2),2)), [] );
        title( situation_objects{oi} );
    end
    end

    



