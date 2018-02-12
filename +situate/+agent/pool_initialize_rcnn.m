function primed_agent_pool = pool_initialize_rcnn( p, im, im_fname )
        
    im_size = [ size(im,1), size(im,2) ];

    num_rcnn_agents_per_obj = 10;
    num_non_rcnn_agents     = 30; % total in initial pool
    
    rcnn_box_dir = {};
    rcnn_box_dir{1}  = 'rcnn box data/dogwalking, negative, all/';
    rcnn_box_dir{2}  = 'rcnn box data/dogwalking, positive, portland all/';
    rcnn_box_dir{3}  = 'rcnn box data/dogwalking, positive, portland test/';
    rcnn_box_dir{4}  = 'rcnn box data/dogwalking, positive, portland train/';
    rcnn_box_dir{5}  = 'rcnn box data/dogwalking, positive, stanford/';
    rcnn_box_dir{6}  = 'rcnn box data/handshaking leftright, negative/';
    rcnn_box_dir{7}  = 'rcnn box data/handshaking leftright, positive all/';
    rcnn_box_dir{8}  = 'rcnn box data/handshaking participants, positive all/';
    rcnn_box_dir{9}  = 'rcnn box data/handshaking participants, sanity all/';
    rcnn_box_dir{10} = 'rcnn box data/pingpong, negative/';
    rcnn_box_dir{11} = 'rcnn box data/pingpong, positive/';
    
    situation_objects = p.situation_objects; % dogwalker dog leash
    situation_object_dirs = {'dog_walker','dog','leash'};
    
    % get csv data
    csv_fnames = cell(1,length(situation_objects));
    csv_data   = cell(1,length(situation_objects));
    
    if num_rcnn_agents_per_obj > 0

        for oi = 1:length(situation_objects)

            % go through each of the box dir entries to see if we can find the csv file that matches the
            % current image file
                [~,fname,~] = fileparts( im_fname );
                di = 1;
                cur_csv_fname = fullfile( rcnn_box_dir{di},situation_object_dirs{oi}, [fname '.csv'] );
                while ~exist(cur_csv_fname,'file') && di < length(rcnn_box_dir)
                    di = di + 1;
                    cur_csv_fname = fullfile( rcnn_box_dir{di},situation_object_dirs{oi}, [fname '.csv'] );
                end
                if ~exist( cur_csv_fname,'file') 
                    % we need to fix the old naming scheme to make it match with the new naming scheme
                    % should just rename all of the csv files at this point? or does it make more sense
                    % to find the old names and update my images? ugh.
                end
                    csv_fnames{oi} = cur_csv_fname;

            % grab box data from the csv file
                csv_data_columns = {'x','y','w','h','confidence','gt iou initial'};
                conf_column = find( strcmp( csv_data_columns, 'confidence' ) );
                temp = importdata( csv_fnames{oi} );
                temp = sortrows( temp, -conf_column );

                num_rcnn_agents_per_obj = min(num_rcnn_agents_per_obj,size(temp,1));
                temp = temp( 1:num_rcnn_agents_per_obj, : );
                csv_data{oi} = temp;
        end

        % see if we need to do resizing for the rcnn boxes
        im_info = imfinfo(im_fname);
        if ~isequal( im_size, [im_info.Height im_info.Width] )

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

    end
        
    num_rcnn_primed_agents = sum( cellfun( @(x) size( x, 1 ), csv_data ) );
    
    
    
    
    total_primed_agents = num_rcnn_primed_agents + num_non_rcnn_agents;
    cur_agent = situate.agent.initialize();
    cur_agent.urgency = 1;
    primed_agent_pool = repmat( cur_agent, total_primed_agents, 1 );
    agents_remove = false( size( primed_agent_pool ) );
    ai = 1;
    for oi = 1:length(situation_objects)
    for bi = 1:size( csv_data{oi}, 1 )
        primed_agent_pool(ai).interest = situation_objects{oi};
        primed_agent_pool(ai).urgency = p.situation_objects_urgency_pre(oi);
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
        if ( r0 > rf ) || ( c0 > cf )
            agents_remove(ai) = true;
        end
        
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
    
    primed_agent_pool( agents_remove ) = [];
    
end
       

    




