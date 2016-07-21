function output_box_xywh = apply_box_adjust_models_mq( box_adjust_model, object_label, im, input_box_xywh, num_adjustment_iterations )
% output_box_xywh = apply_box_adjust_models_mq( box_adjust_model, object_label, im, input_box_xywh, num_adjustment_iterations )


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
    
   % hf = figure('Selected','on');
   % I = im;
   % B = insertShape(I,'Rectangle',input_box_xywh,'Color','blue','LineWidth',3);
   
%max and min percentage for primary shift factor, decreases slightly for each call to up, down, left, and right
    shift_max = 0.4; 
    shift_min = 0.3;
%counts up, down, left, and right translations, expands box after 5, not in
%use currently
    t_count = 0;
%scale factor for contract and expand, decreases slightly when called
    s3 = 0.1;
    
    for cur_iteration = 1:num_adjustment_iterations
        
        s = (shift_max - shift_min) * rand + shift_min;
        %secondary shift, for example a small up or down with a primary right or left
        %movement
        s2 = 0.3 * rand - 0.15;
        
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
               % B3 = insertShape(B,'Rectangle',[c0,r0,w,h],'Color','red','LineWidth',3);
               % hf, imshow(B3);
                
                
                % should break and return the current box
                break
            case 'up'
                % move down a little
                r0 = r0 + s*h;
                rf = rf + s*h;
                c0 = c0 + s2*w;
                cf = cf + s2*w;
                shift_max = shift_max - 0.025;
                shift_min = shift_min - 0.025;
                t_count = t_count + 1;
            case 'down'
                % move up a little
                r0 = r0 - s*h;
                rf = rf - s*h;
                c0 = c0 + s2*w;
                cf = cf + s2*w;
                shift_max = shift_max - 0.025;
                shift_min = shift_min - 0.025;
                t_count = t_count + 1;
            case 'left'
                % move right alittle
                c0 = c0 + s*w;
                cf = cf + s*w;
                r0 = r0 + s2*h;
                rf = rf + s2*h;
                shift_max = shift_max - 0.025;
                shift_min = shift_min - 0.025;
                t_count = t_count + 1;
            case 'right'
                % move left a little
                c0 = c0 - s*w;
                cf = cf - s*w;
                r0 = r0 + s2*h;
                rf = rf + s2*h;
                shift_max = shift_max - 0.025;
                shift_min = shift_min - 0.025;
                t_count = t_count + 1;
            case 'expand'
                % contract a little
                r0 = r0 + s3*h;
                rf = rf - s3*h;
                c0 = c0 + s3*w;
                cf = cf - s3*w;
                s3 = s3 - 0.025;
            case 'contract'
                % expand a little
                r0 = r0 - s3*h;
                rf = rf + s3*h;
                c0 = c0 - s3*w;
                cf = cf + s3*w;
                s3 = s3 - 0.025;
            case 'background'
                % don't know...break?
                break
            otherwise
                error('unrecognized alignment prediciton');
      
        end

    
        if s3 < 0.05
            s3 = 0.2;
        end
%         if t_count == 5
%             shift_max = 0.4;
%             shift_min = 0.3;
%             t_count = 0;
%             if strcmp(object_label,'dogwalker') == 1
%                 w1 = w * 1.2;
%                 h1 = w1 * 1.8;
%                 h_ratio = h/h1;
%                 w_ratio = w/w1;
%                 r0 = r0 - h_ratio * h;
%                 rf = rf + h_ratio * h;
%                 c0 = c0 - w_ratio * w;
%                 cf = cf + w_ratio * w;
%             else
%                 w1 = w * 1.4;
%                 h1 = w1;
%                 h_ratio = h1/h;
%                 w_ratio = w1/w;
%                 r0 = r0 - h_ratio * h;
%                 rf = rf + h_ratio * h;
%                 c0 = c0 - w_ratio * w;
%                 cf = cf + w_ratio * w;
%             end
%         end
        
 
        % correct boxes for image edges
        r0 = round(max(r0,1));
        rf = round(min(rf,size(im,1)));
        c0 = round(max(c0,1));
        cf = round(min(cf,size(im,2)));
        
        w = cf - c0 + 1;
        h = rf - r0 + 1;
       % B2 = insertShape(B,'Rectangle',[c0,r0,w,h],'Color','green','LineWidth',3);
       % hf, imshow(B2);

    end

    
    
    
    output_box_xywh = [c0, r0, cf-c0+1, rf-r0+1];
%    close
    
end










