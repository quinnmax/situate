function [output_box_xywh, cur_iteration] = apply_box_adjust_models_mq( box_adjust_model, object_label, im, input_box_xywh, num_adjustment_iterations )

% output_box_xywh = apply_box_adjust_models_mq( box_adjust_model, object_label, im, input_box_xywh, num_adjustment_iterations )
%
% box_adjust_model = 
% 
%                  objects_in_indexing_order: {'dogwalker'  'dog'  'leash'}
%               alignments_in_indexing_order: {'centered'    'up'    'down'    'left'    'right'    'expand'    'contract'    'background'}
%                  box_adjustment_models_1v1: {3x28 cell} ( of 1x1 Classification SVMs )
%     box_adjustment_models_1v1_descriptions: {3x28 cell}
%                            fnames_lb_train: {1x10 cell}
%                                          p: [1x1 struct]

    % figure out what object index we have based on the interest
    object_index = find(strcmp(box_adjust_model.objects_in_indexing_order, object_label ));

    % grab the current crop
    c0 = input_box_xywh(1);
    r0 = input_box_xywh(2);
    w  = input_box_xywh(3);
    h  = input_box_xywh(4);
    rf = r0 + h - 1;
    cf = c0 + w - 1;
    
    % correct boxes for image edges
    r0 = max(r0,1);
    rf = min(rf,size(im,1));
    c0 = max(c0,1);
    cf = min(cf,size(im,2));
    
    s = .1; % step scale
    
    for cur_iteration = 1:num_adjustment_iterations

        cur_crop = im(r0:rf,c0:cf,:);
        cur_feature_vect = box_adjust_model.feature_extraction_function( cur_crop );

        % initialize votes
        votes = [];
        for ai = 1:length(box_adjust_model.alignments_in_indexing_order)
            cur_alignment = box_adjust_model.alignments_in_indexing_order{ai};
            votes.(cur_alignment) = 0;
        end

        % get the alignment prediction from each model
        % add to the vote counts
        posteriors = zeros(length(box_adjust_model.box_adjustment_models_1v1(object_index,:)),2); % not currently used at all
        for mi = 1:length( box_adjust_model.box_adjustment_models_1v1(object_index,:) )

           [class_prediction,posteriors(mi,:)] = predict(  box_adjust_model.box_adjustment_models_1v1{object_index,mi}, cur_feature_vect  );
           votes.(class_prediction{:}) = votes.(class_prediction{:}) + 1;

        end

        alignments  = fieldnames(votes);
        [~,winning_ind] = max(struct2array(votes));
        predicted_alignment = alignments{winning_ind};
        
        switch predicted_alignment
            case 'centered'
                % should break and return the current box
                break
            case 'up'
                % move down a little
                r0 = r0 + s*h;
                rf = rf + s*h;
            case 'down'
                % move up a little
                r0 = r0 - s*h;
                rf = rf - s*h;
            case 'left'
                % move right alittle
                c0 = c0 + s*w;
                cf = cf + s*w;
            case 'right'
                % move left a little
                c0 = c0 - s*w;
                cf = cf - s*w;
            case 'expand'
                % contract a little
                r0 = r0 + s/2*h;
                rf = rf - s/2*h;
                c0 = c0 + s/2*w;
                cf = cf - s/2*w;
            case 'contract'
                % expand a little
                r0 = r0 - s/2*h;
                rf = rf + s/2*h;
                c0 = c0 - s/2*w;
                cf = cf + s/2*w;
            case 'background'
                % don't know...break?
                break
            otherwise
                error('unrecognized alignment prediciton');
        end
        
        % make small, random adjustment to the box center
        r_delta = .1 * h * randn(1)/3;
        c_delta = .1 * w * randn(1)/3;
        r0 = r0 + r_delta;
        rf = rf + r_delta;
        c0 = c0 + c_delta;
        cf = cf + c_delta;
        
        % correct boxes for image edges
        r0 = round(max(r0,1));
        rf = round(min(rf,size(im,1)));
        c0 = round(max(c0,1));
        cf = round(min(cf,size(im,2)));
        
        % update width and height
        w = cf-c0+1;
        h = rf-r0+1;

    end

    output_box_xywh = [c0, r0, cf-c0+1, rf-r0+1];
    
end










