function [workspace_return, imported_data] = csvs2workspace( csv_directory, im_fname, situation_struct  )

% workspace_return = csvs2workspace( csv_directory, im_fname, situation_struct  );
%
% box information should be in csv_directory/situation_description/object_type/im_fname.csv
% im_fname
% situation_struct
%   description : str
%   situation_objects : cellstr

    lb_fname = [fileparts_mq(im_fname,'path/name') '.json'];

    situation_support_func = @(x) prod( x + .01 ) .^ (1/length(x));

    num_objects = length(situation_struct.situation_objects);            

    w = warning('off','all'); % i don't care about the gps info missing
    im_info = imfinfo(im_fname);
    warning(w);
    im_size = [im_info.Height im_info.Width];
    

    cur_image_boxes_r0rfc0cf = nan( num_objects, 4 ); 
    conf_values = nan(1,num_objects);

    imported_data = cell(1,num_objects);
    
    for oi = 1:num_objects

        cur_obj = situation_struct.situation_objects{oi};
        try
            cur_csv_name = fullfile( csv_directory, situation_struct.situation_description, cur_obj, [fileparts_mq(im_fname,'name'), '.csv']);
        catch
            cur_csv_name = fullfile( csv_directory, situation_struct.desc, cur_obj, [fileparts_mq(im_fname,'name'), '.csv']);
        end
        assert( isfile( cur_csv_name ) );

        % csv_data_columns = {'x','y','w','h','confidence','gt iou maybe'};
        temp = importdata( cur_csv_name );
        temp = sortrows(temp,-5);
        imported_data{oi} = temp;

        ti = 1;
        [success,proposed_box_r0rfc0cf] = box_fix( temp(ti,1:4), 'xywh', im_size);
        
        if isempty(cur_image_boxes_r0rfc0cf)
            cur_image_ious = [];
        else
            cur_image_ious = intersection_over_union( proposed_box_r0rfc0cf, cur_image_boxes_r0rfc0cf, 'r0rfc0cf','r0rfc0cf' );
        end

        while any( cur_image_ious > .5 )
            ti = ti + 1;
            [~,proposed_box_r0rfc0cf] = box_fix( temp(ti,1:4), 'xywh', im_size);
            cur_image_ious = intersection_over_union( proposed_box_r0rfc0cf, cur_image_boxes_r0rfc0cf, 'r0rfc0cf','r0rfc0cf' );
        end

        cur_image_boxes_r0rfc0cf(oi,:) = proposed_box_r0rfc0cf;
        conf_values(oi)                = temp(ti,5);

    end

    workspace_return = [];
    workspace_return.boxes_r0rfc0cf = cur_image_boxes_r0rfc0cf;
    workspace_return.labels = situation_struct.situation_objects; 
    workspace_return.im_size = im_size;
    workspace_return.internal_support = conf_values;
    workspace_return.external_support = zeros(size(conf_values));;
    workspace_return.total_support = conf_values;
    workspace_return.situation_support = situation_support_func( conf_values );
    workspace_return.iteration = nan;
    if exist(lb_fname,'file')
        workspace_return = situate.workspace_score(workspace_return, lb_fname, situation_struct );
    else
        workspace_return.GT_IOU = nan(1,num_objects);
    end
            
end