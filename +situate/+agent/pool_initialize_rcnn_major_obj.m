function [agent_pool,total_cnn_calls] = pool_initialize_rcnn_major_obj( situation_struct, im, im_fname, ~, varargin )

% primed_agent_pool = pool_initialize_rcnn( situation_struct, im, im_fname, learned_models );
%
% rcnn box data for each object in the image should be found in
%   external box data/rcnn boxes/[situation desc]/[object desc]/[image name].csv
% 

    total_cnn_calls = 0;

    debug_boxes = false;
    
    im_size = [ size(im,1), size(im,2) ];
    situation_objects = situation_struct.situation_objects;
    
    csv_data_columns = {'x','y','w','h','confidence','gt iou initial'}; % note to self
    conf_column = find( strcmp( csv_data_columns, 'confidence' ) );
    
    
    % get boxes for each situation object
    csv_data_raw = cell(1,length(situation_objects));
    for oi = 1:length(situation_objects)
        cur_obj = situation_objects{oi};
        csv_fname = fullfile( 'external box data/rcnn boxes major objects', situation_struct.situation_description, cur_obj, [fileparts_mq( im_fname, 'name' ) '.csv'] );
        if exist( csv_fname,'file')
            csv_data_raw{oi} = importdata( csv_fname );
        else
            csv_data_raw{oi} = nan(0,numel(csv_data_columns));
        end
    end
    
    % remove 0 conf boxes
    for oi = 1:length(situation_objects)
        csv_data_raw{oi}( csv_data_raw{oi}(:,conf_column)<.1, : ) = [];
    end
    
    % debug
    if debug_boxes
        figure('Name', '1 raw proposal/rcnn conf, fixed conf threshold');
        for oi = 1:length(situation_objects)
            subplot(1,numel(situation_objects),oi);
            imshow( im );
            title(situation_struct.situation_objects{oi});
            hold on;
            draw_box( csv_data_raw{oi}(:,1:4),'xywh', 'LineWidth', 1 );
        end
        hold off;
    end
    
    % do non-max supression
    csv_data_nonmaxsupress = cell(1,length(situation_objects));
    for oi = 1:length(situation_objects)
        cur_csv_data = csv_data_raw{oi};
        overlap_supression_threshold = .5;
        rows_supress = non_max_supression( cur_csv_data(:,1:4), cur_csv_data(:,conf_column), overlap_supression_threshold, 'xywh' );
        cur_csv_data(rows_supress,:) = [];
        csv_data_nonmaxsupress{oi} = cur_csv_data;
    end
    
    % debug
    if debug_boxes
        figure('Name', '2 post non-max supression');
        for oi = 1:length(situation_objects)
            subplot(1,numel(situation_objects),oi);
            imshow( im );
            title(situation_struct.situation_objects{oi});
            hold on;
            draw_box( csv_data_nonmaxsupress{oi}(:,1:4),'xywh', 'LineWidth', 1 );
        end
        hold off;
    end
    
    csv_data = cell(1,length(situation_objects));
    for oi = 1:length(situation_objects)
        csv_data{oi} = sortrows( csv_data_nonmaxsupress{oi}, -conf_column );
    end
      
    
    % consider resizing
    im_info = imfinfo(im_fname);
    if ~isequal( im_size, [im_info.Height im_info.Width] )
        linear_scaling_factor = sqrt( prod(im_size) / prod([im_info.Height im_info.Width]) );
        for oi = 1:length(situation_objects)
            csv_data{oi}(:,1:4) = linear_scaling_factor * csv_data{oi}(:,1:4);
        end 
    end
     
    % debug
    if debug_boxes
        figure('Name', '3 post non-max supression, rescaled');
        for oi = 1:length(situation_objects)
            subplot(1,numel(situation_objects),oi);
            imshow( im );
            title(situation_struct.situation_objects{oi});
            hold on;
            draw_box( csv_data{oi}(:,1:4),'xywh', 'LineWidth', 1 );
        end
        hold off;
    end
    
    
    % generate primed agent pool
    total_scouts = sum(cellfun( @(x) size(x,1), csv_data ));
    
    cur_agent = situate.agent.initialize();
    cur_agent.urgency = 5;
    agent_pool = repmat( cur_agent, 1, total_scouts );
    agents_remove = false( size( agent_pool ) );
    
    ai = 1;
    for oi = 1:length(situation_objects)
    for bi = 1:size( csv_data{oi}, 1 )
        
        agent_pool(ai).interest = situation_objects{oi};
        if isfield(situation_struct,'situation_objects_urgency_pre')
            agent_pool(ai).urgency = situation_struct.situation_objects_urgency_pre(oi);
        end
        x  = csv_data{oi}(bi,1);
        y  = csv_data{oi}(bi,2);
        w  = csv_data{oi}(bi,3);
        h  = csv_data{oi}(bi,4);
        
        r0 = y;
        rf = y + h - 1;
        c0 = x;
        cf = x + w - 1;
        
        r0 = round(r0);
        rf = round(rf);
        c0 = round(c0);
        cf = round(cf);
        
        % fix row,col
        r0 = max(r0,1);
        rf = min(rf,im_size(1));
        c0 = max(c0,1);
        cf = min(cf,im_size(2));
        
        % fix x,y
        x = c0;
        y = r0;
        w = cf - c0 + 1;
        h = rf - r0 + 1;
        
        % see if it should get dropped
        if ( r0 >= rf ) || ( c0 >= cf )
            agents_remove(ai) = true;
        end
        
        xc = x + w/2 - .5;
        yc = y + h/2 - .5;
        aspect_ratio = w/h;
        area_ratio = (w*h) / prod(im_size);
        agent_pool(ai).box.r0rfc0cf = [r0 rf c0 cf];
        agent_pool(ai).box.xywh     = [ x  y  w  h];
        agent_pool(ai).box.xcycwh   = [xc yc  w  h];
        agent_pool(ai).box.aspect_ratio = aspect_ratio;
        agent_pool(ai).box.area_ratio   = area_ratio;
        agent_pool(ai).history = 'primedRCNN';
        ai = ai + 1;
    end
    end
    
    agent_pool( agents_remove ) = [];
    
    if debug_boxes
        figure('Name', '4 as represented in pool');
        for oi = 1:length(situation_objects)
            subplot(1,numel(situation_objects),oi);
            imshow( im );
            title(situation_struct.situation_objects{oi});
            is_cur_obj = strcmp(situation_objects{oi}, {agent_pool.interest});
            temp = [agent_pool(is_cur_obj).box];
            hold on;
            draw_box( vertcat(temp.r0rfc0cf),'r0rfc0cf', 'LineWidth', 1 );
        end
        hold off;
    end
    
end









    




