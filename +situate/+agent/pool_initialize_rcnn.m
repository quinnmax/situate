function primed_agent_pool = pool_initialize_rcnn( p, im, im_fname, ~, varargin )

% primed_agent_pool = pool_initialize_rcnn( p, im, im_fname, learned_models, [num_rcnn_agents_per_obj], [num_non_rcnn_agents] );
%
% num_rcnn_agents_per_obj [optionally] sets how many of the top rcnn boxes are added to the initial agent pool
%   default is 10
% num_non_rcnn_agents [optionally] is the number of unassigned agents. they will sample and interest and location
%   default is 30
        

    if length(varargin) >= 1
        num_rcnn_agents_per_obj = varargin{1};
    else
        num_rcnn_agents_per_obj = 10;
    end
    
    if length(varargin) >= 2
        num_non_rcnn_agents = varargin{2};
    else
        num_non_rcnn_agents     = 30; % total in initial pool
    end
    
    
    
    
    
    im_size = [ size(im,1), size(im,2) ];
    situation_objects = p.situation_objects;
    
    situation_objects_str = sort(p.situation_objects);
    situation_objects_str = [situation_objects_str{:}];
    
    rcnn_box_dir = {};
    
    switch situation_objects_str
        case 'dogdogwalkerleash'
            rcnn_box_dir{1}  = 'rcnn box data/dogwalking, positive/';
            rcnn_box_dir{2}  = 'rcnn box data/dogwalking, negative/';
            rcnn_box_dir{3}  = 'rcnn box data/dogwalking, hard negative/';
        case 'personsomethingsomethingperson'
            rcnn_box_dir{1}  = 'rcnn box data/handshaking, positive/';
            rcnn_box_dir{2}  = 'rcnn box data/handshaking, negative/';
            rcnn_box_dir{3}  = 'rcnn box data/handshaking, hard negative/';
        case 'pingsomethingsomethingpong'
            rcnn_box_dir{1} = 'rcnn box data/pingpong, positive/';
            rcnn_box_dir{2} = 'rcnn box data/pingpong, negative/';
            rcnn_box_dir{3} = 'rcnn box data/pingpong, hard negative/';
        otherwise
            error('check objects str');
    end
    
    
    
    csv_data = cell(1,length(situation_objects));
    if num_rcnn_agents_per_obj > 0
        csv_data = rcnn_boxes_from_csv( p, im_fname, rcnn_box_dir );
    end
    
    
    
    % remove excess boxes
    for oi = 1:length(situation_objects)
        num_rcnn_agents_per_obj = min(num_rcnn_agents_per_obj,size(csv_data{oi},1));
        csv_data{oi} = csv_data{oi}( 1:num_rcnn_agents_per_obj, : );
    end
     
    % consider resizing
    im_info = imfinfo(im_fname);
    if ~isequal( im_size, [im_info.Height im_info.Width] )
        linear_scaling_factor = sqrt( prod(im_size) / prod([im_info.Height im_info.Width]) );
        for oi = 1:length(situation_objects)
            csv_data{oi}(1:4,:) = linear_scaling_factor * csv_data{oi}(1:4,:);
        end 
    end
     
    % visualize boxes
    check_boxes = false;
    if check_boxes
        imshow( im );
        colors = hot(3);
        hold on;
        for oi = 1:length(situation_objects)
            draw_box( csv_data{oi}(:,1:4),'xywh', 'Color', colors(oi,:), 'LineWidth', 1 );
        end
        hold off;
    end
    
    
     
     
     
     
     
     
     
     
     
    % now do the actual agent pool priming
        
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
        if isfield(p,'situation_objects_urgency_pre')
            primed_agent_pool(ai).urgency = p.situation_objects_urgency_pre(oi);
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


















function csv_data = rcnn_boxes_from_csv( situation_struct, im_fname, rcnn_box_dir )

    % see what objects are present in the rcnn box directory we were passed
    situation_objects = situation_struct.situation_objects;
    dir_data = dir( rcnn_box_dir{1} );
    dir_objects = {dir_data.name};
    
    % get correspondance between situation objects and objects with folders
    corr_obj_dir = false( length(situation_objects), length( {dir_data.name} ) );
    for oi = 1:length(situation_objects)
    for di = 1:length({dir_data.name})
        cur_obj = strrep( situation_objects{oi}, '_', '');
        cur_dir_name = strrep( dir_data(di).name, '_', '');
        if strcmp( cur_obj, cur_dir_name ), corr_obj_dir(oi,di) = true; end
    end
    end
    
    % try again, but be a little more lenient if there were empty rows 
    % 'dog' will get data from 'dog1' and 'dog2' directories if it didn't find a perfect match already
    corr_obj_dir_soft = false( length(situation_objects), length( {dir_data.name} ) );
    for oi = 1:length(situation_objects)
    if all(~corr_obj_dir(oi,:))
        for di = 1:length({dir_data.name})
            cur_obj = strrep( situation_objects{oi}, '_', '');
            cur_dir_name = strrep( dir_data(di).name, '_', '');
            if ~isempty(strfind( cur_obj, cur_dir_name )), corr_obj_dir_soft(oi,di) = true; end
        end
    end
    end
    
    corr_obj_dir = or( corr_obj_dir, corr_obj_dir_soft );
    
    if any( sum(corr_obj_dir,2) > 1 )
        error('need to fix this one to many issue');
    end
    
    
    
    % remove irrelevant folders for our situation
    irrelevant_inds = ~any(corr_obj_dir);
    corr_obj_dir(:,irrelevant_inds) = [];
    dir_objects(irrelevant_inds) = [];
    
    
    
    % find the directory that contains the rcnn data for our current image
    rcnn_box_dir_ind = [];
    for di = 1:length( rcnn_box_dir )
        assert( logical( exist( rcnn_box_dir{di}, 'dir' ) ) );
        assert( logical( exist( fullfile( rcnn_box_dir{di}, dir_objects{1} ), 'dir' ) ) );

        proposed_name = fullfile( rcnn_box_dir{di}, dir_objects{1}, [fileparts_mq(im_fname,'name'), '.csv'] );
        if exist( proposed_name, 'file' )
            rcnn_box_dir_ind = di;
        end

    end
    
    
    % get relevant csv files
    csv_fnames = cell(1,length(situation_objects));
    csv_data   = cell(1,length(situation_objects));
    for oi = 1:length(situation_objects)
        csv_fnames{oi} = fullfile( rcnn_box_dir{rcnn_box_dir_ind}, dir_objects{corr_obj_dir(oi,:)},[fileparts_mq(im_fname,'name'), '.csv']);
    
        % grab box data from the csv file
        csv_data_columns = {'x','y','w','h','confidence','gt iou initial'}; % note to self
        conf_column = find( strcmp( csv_data_columns, 'confidence' ) );
        temp = importdata( csv_fnames{oi} );
        temp = sortrows( temp, -conf_column );
        csv_data{oi} = temp;
      
    end
    
   
   
end
       

    




