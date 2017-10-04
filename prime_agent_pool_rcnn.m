function primed_agent_pool = prime_agent_pool_rcnn( im_size, im_fname, p )
% [primed_boxes_r0rfc0cf, primed_agent_pool] = prime_agent_pool_rcnn( im_size, im_fname, p );

    num_rcnn_agents_per_obj = 10;
    num_non_rcnn_agents     = 10; % total in initial pool
    
    rcnn_box_dir = 'rcnn box data/dogwalking, positive, portland all/';
    situation_objects = p.situation_objects; % dogwalker dog leash
    situation_object_dirs = {'dog_walker','dog','leash'};

    csv_fnames = cell(1,length(situation_objects));
    csv_data   = cell(1,length(situation_objects));
    for oi = 1:length(situation_objects)
        [~,fname,~] = fileparts( im_fname );
        csv_fnames{oi} = fullfile( rcnn_box_dir,situation_object_dirs{oi}, [fname '.csv'] );
        assert( logical( exist(csv_fnames{oi},'file') ) );
        
        csv_data_columns = {'x','y','w','h','confidence','gt iou initial'};
        conf_column = find( strcmp( csv_data_columns, 'confidence' ) );
        temp = importdata( csv_fnames{oi} );
        temp = sortrows( temp, -conf_column );
        
        num_rcnn_agents_per_obj = min(num_rcnn_agents_per_obj,size(temp,1));
        temp = temp( 1:num_rcnn_agents_per_obj, : );
        csv_data{oi} = temp;
    end
    
    im_info = imfinfo(im_fname);
    if ~isequal( im_size, [im_info.Height im_info.Width] )
        % need to resize the rcnn boxes
        linear_scaling_factor = sqrt( prod(im_size) / prod([im_info.Height im_info.Width]) );
        for oi = 1:length(situation_objects)
            csv_data{oi}(1:4,:) = linear_scaling_factor * csv_data{oi}(1:4,:);
        end
        
        check_boxes = false;
        if check_boxes
            imshow( imresize( imread( im_fname ), linear_scaling_factor ) );
            colors = hot(3);
            hold on;
            for oi = 1:length(situation_objects)
                draw_box( csv_data{oi}(:,1:4),'xywh', 'Color', colors(oi,:), 'LineWidth', 1 );
            end
            hold off;
        end
        
    end
    
    total_primed_agents = sum( cellfun( @(x) size( x, 1 ), csv_data ) ) + num_non_rcnn_agents;
    primed_agent_pool = repmat( situate.agent_initialize(), total_primed_agents, 1 );
    ai = 1;
    for oi = 1:length(situation_objects)
    for bi = 1:size( csv_data{oi}, 1 )
        primed_agent_pool(ai).interest = situation_objects{oi};
        primed_agent_pool(ai).urgency = p.situation_objects_urgency_pre.( primed_agent_pool(ai).interest );
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
        
        xc = x + w/2 - .5;
        yc = y + h/2 - .5;
        aspect_ratio = w/h;
        area_ratio = (w*h) / prod(im_size);
        primed_agent_pool(ai).box.r0rfc0cf = [r0 rf c0 cf];
        primed_agent_pool(ai).box.xywh     = [ x  y  w  h];
        primed_agent_pool(ai).box.xcycwh   = [xc yc  w  h];
        primed_agent_pool(ai).box.aspect_ratio = aspect_ratio;
        primed_agent_pool(ai).box.area_ratio   = area_ratio;
        primed_agent_pool(ai).history = 'primedRCNN';
        ai = ai + 1;
    end
    end
    
end
       

    



