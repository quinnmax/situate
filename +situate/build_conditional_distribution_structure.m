
function conditional_dist_struct = build_conditional_distribution_structure( fnames_lb, p )

    % build the models
    %
    %   boxes are provided in xywh format (based on images that are unit area and centered at 0) 
    %   but the model produces centers and w,h data
    %
    %   this has a bunch of redundancy, but who cares. the thing you're looking
    %   for is more likely to be where you look. they're all static, so it's no
    %   biggie.

    image_data = situate.image_data( fnames_lb );
    image_data = situate.image_data_label_adjust( image_data, p );
    
    
    objects_indexing_order = [ p.situation_objects, 'none' ];
    num_situation_objs     = length( p.situation_objects );
    models                 = cell( num_situation_objs, num_situation_objs+1, num_situation_objs+1, num_situation_objs+1 );
    model_descriptions     = cell( num_situation_objs, num_situation_objs+1, num_situation_objs+1, num_situation_objs+1 );
    
    for ti = 1:length( p.situation_objects )
    for ai = 1:length( objects_indexing_order )
    for bi = 1:length( objects_indexing_order )
    for ci = 1:length( objects_indexing_order )

        boxes_t_xywh = zeros( length(image_data), 4 );
        boxes_a_xywh = zeros( length(image_data), 4 );
        boxes_b_xywh = zeros( length(image_data), 4 );
        boxes_c_xywh = zeros( length(image_data), 4 );

        for ii = 1:length(image_data)

            cur_labels     = image_data(ii).labels_adjusted;
            cur_boxes_xywh = image_data(ii).boxes_normalized_xywh;

            cur_object_t = objects_indexing_order{ti};
            cur_ind = find(strcmp(cur_object_t,cur_labels),1,'first');
            if ~isempty(cur_ind)
                boxes_t_xywh(ii,:) = cur_boxes_xywh(cur_ind,:);
                cur_labels(cur_ind) = [];
                cur_boxes_xywh(cur_ind,:) = [];
            else
                boxes_t_xywh = [];
            end

            cur_object_a = objects_indexing_order{ai};
            cur_ind = find(strcmp(cur_object_a,cur_labels),1,'first');
            if ~isempty(cur_ind)
                boxes_a_xywh(ii,:) = cur_boxes_xywh(cur_ind,:);
                cur_labels(cur_ind) = [];
                cur_boxes_xywh(cur_ind,:) = [];
            else
                boxes_a_xywh = [];
            end

            cur_object_b = objects_indexing_order{bi};
            cur_ind = find(strcmp(cur_object_b,cur_labels),1,'first');
            if ~isempty(cur_ind)
                boxes_b_xywh(ii,:) = cur_boxes_xywh(cur_ind,:);
                cur_labels(cur_ind) = [];
                cur_boxes_xywh(cur_ind,:) = [];
            else
                boxes_b_xywh = [];
            end

            cur_object_c = objects_indexing_order{ci};
            cur_ind = find(strcmp(cur_object_c,cur_labels),1,'first');
            if ~isempty(cur_ind)
                boxes_c_xywh(ii,:) = cur_boxes_xywh(cur_ind,:);
                cur_labels(cur_ind) = [];
                cur_boxes_xywh(cur_ind,:) = [];
            else
                boxes_c_xywh = [];
            end

        end

        temp = situate.box_model_train( boxes_t_xywh, boxes_a_xywh, boxes_b_xywh, boxes_c_xywh );
        models{ti,ai,bi,ci} = temp;
        model_descriptions{ti,ai,bi,ci} = sprintf('%s xy conditioned on %s xy, %s xy, %s xy', cur_object_t, cur_object_a, cur_object_b, cur_object_c );

    end
    end
    end
    end

    
    conditional_dist_struct = [];
    conditional_dist_struct.models = models;
    conditional_dist_struct.model_descriptions = model_descriptions;
    conditional_dist_struct.labels_in_indexing_order = [p.situation_objects 'none'];
    conditional_dist_struct.fnames_lb_train = fnames_lb;
    
end




