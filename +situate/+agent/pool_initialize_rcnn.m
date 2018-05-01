function primed_agent_pool = pool_initialize_rcnn( situation_struct, im, im_fname, ~, varargin )

% primed_agent_pool = pool_initialize_rcnn( situation_struct, im, im_fname, learned_models, [num_rcnn_agents_per_obj], [num_non_rcnn_agents] );
%
% num_rcnn_agents_per_obj [optionally] sets how many of the top rcnn boxes are added to the initial agent pool
%   default is 10
% num_non_rcnn_agents [optionally] is the number of unassigned agents. they will sample and interest and location
%   default is 30
%
% rcnn box data for each object in the image should be found in
%   external box data/rcnn boxes/[situation desc]/[object desc]/[image name].csv
%



    % process inputs
    if length(varargin) >= 1
        num_rcnn_agents_per_obj = varargin{1};
    else
        num_rcnn_agents_per_obj = 10;
    end
    
    if length(varargin) >= 2
        num_non_rcnn_agents = varargin{2};
    else
        num_non_rcnn_agents = 30; % total in initial pool
    end
    
    
    
    im_size = [ size(im,1), size(im,2) ];
    situation_objects = situation_struct.situation_objects;
    
    % get boxes for each situation object
    csv_data = cell(1,length(situation_objects));
    for oi = 1:length(situation_objects)
        cur_obj = situation_objects{oi};
        csv_fname = fullfile( 'external box data/rcnn boxes', situation_struct.situation_description, cur_obj, [fileparts_mq( im_fname, 'name' ) '.csv'] );
        assert( isfile(csv_fname) );
        csv_data_columns = {'x','y','w','h','confidence','gt iou initial'}; % note to self
        conf_column = find( strcmp( csv_data_columns, 'confidence' ) );
        temp = importdata( csv_fname );
        temp = sortrows( temp, -conf_column );
        num_boxes = min( num_rcnn_agents_per_obj, size(temp,1));
        csv_data{oi} = temp(1:num_boxes,:);
    end
  
    % consider resizing
    im_info = imfinfo(im_fname);
    if ~isequal( im_size, [im_info.Height im_info.Width] )
        linear_scaling_factor = sqrt( prod(im_size) / prod([im_info.Height im_info.Width]) );
        for oi = 1:length(situation_objects)
            csv_data{oi}(:,1:4) = linear_scaling_factor * csv_data{oi}(:,1:4);
        end 
    end
     
    % visualize boxes
    visualize_boxes = false;
    if visualize_boxes
        imshow( im );
        colors = hot(3);
        hold on;
        for oi = 1:length(situation_objects)
            draw_box( csv_data{oi}(:,1:4),'xywh', 'Color', colors(oi,:), 'LineWidth', 1 );
        end
        hold off;
    end
    
    % turn boxes into an actual primed agent pool
    num_rcnn_primed_agents = sum( cellfun( @(x) size( x, 1 ), csv_data ) );
    total_primed_agents = num_rcnn_primed_agents + num_non_rcnn_agents;
    cur_agent = situate.agent.initialize();
    cur_agent.urgency = 5;
    primed_agent_pool = repmat( cur_agent, total_primed_agents, 1 );
    agents_remove = false( size( primed_agent_pool ) );
    ai = 1;
    for oi = 1:length(situation_objects)
    for bi = 1:size( csv_data{oi}, 1 )
        primed_agent_pool(ai).interest = situation_objects{oi};
        if isfield(situation_struct,'situation_objects_urgency_pre')
            primed_agent_pool(ai).urgency = situation_struct.situation_objects_urgency_pre(oi);
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









    




