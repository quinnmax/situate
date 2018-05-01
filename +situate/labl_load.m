


function [lb_struct, lb_structs_possible] = labl_load( label_file_name, varargin )

    % [lb_struct, lb_structs_possible] = labl_load( label_file_name, [situation_struct]  );
    %
    %     data.labels_raw = labels_raw;
    % 
    %     data.boxes_xywh             = boxes_xywh;
    %     data.boxes_xcycwh           = boxes_xcycwh;
    %     data.boxes_r0rfc0cf         = boxes_r0rfc0c0f;
    %     
    %     % normalized boxes are for images assumed to be zero centered and
    %     % unit area. used for situation models
    %     data.boxes_normalized_xywh      = boxes_normalized_xywh;
    %     data.boxes_normalized_xcycwh    = boxes_normalized_xcycwh;
    %     data.boxes_normalized_r0rfc0cf  = boxes_normalized_r0rfc0cf;
    % 
    %     data.box_area_ratio   = box_area_ratio;
    %     data.box_aspect_ratio = box_aspect_ratio;
    % 
    %     data.im_w = im_w;
    %     data.im_h = im_h;
    % 
    %     data.fname_lb = label_file_name;
    %
    %       situation_struct should have fields
    %           situation_objects
    %           situation_objects_possible labels
    %
    %   if there's ambiguity in the object label assignments, one possible labeling is returned (at
    %   random from among options) and all of the options are returned in lb_structs_possible
    %
    %   the ambiguity arrises when constituent objects of the situation have the same set of
    %   possible labels. for example, the situaiton definition for 'handshaking' might be
    %       participant1 : { 'person-facing-left', 'person-facing-right', 'person', 'dog'  }
    %       participant2 : { 'person-facing-left', 'person-facing-right', 'person'm 'dog'  }
    %       handshake :    { 'shaking-hands', 'high-fiving-hands' }
    %   both participant objects have the same set of possible labels, so the assignment of each to
    %   the actual objects in an image is arbitrary. one of the consistent labelings of an image
    %   will be returned in lb_struct, and both possible labelings will be returned in
    %   lb_structs_possible

    
    
    %% input proccessing and routing
    
        if isempty( label_file_name )
            lb_struct = [];
            lb_structs_possible = [];
            return;
        end

        if isempty(varargin) || isempty(varargin{1})
            situation_struct = [];
        else
            situation_struct = varargin{1};
        end

        % if it's a directory, get data from each label
            if ischar(label_file_name) && isdir(label_file_name)
                data_path = label_file_name;
                dir_data = dir([data_path '*.json']);
                path_and_fnames = cellfun( @(x) fullfile( data_path, x ), {dir_data.name}, 'UniformOutput', false );
                lb_struct = situate.labl_load(path_and_fnames,situation_struct);
                
                if isempty( lb_struct )
                    lb_struct = situate.labl_load_old( label_file_name, varargin );
                    if ~isempty(lb_struct)
                        warning('only found old label format, using that');
                        return;
                    end
                end
                  
                return;
            end

        % if it's a cell, get data from each entry
            if iscell(label_file_name)
                lb_struct = cellfun( @(x) situate.labl_load(x,situation_struct), label_file_name, 'UniformOutput', false );
                if all( cellfun( @(x) ~isempty(x), lb_struct ) )
                    lb_struct = [lb_struct{:}];
                end
                return;
            end

        % if it's a single file, see if we can find the associated label file
            lb_struct = [];
            [~,~,ext] = fileparts( label_file_name);
            if strcmp( ext, '.json' )
                % carry on
            else
                % if it's anything else, like jpg or labl, see if the json is there
                if exist( [label_file_name(1:end-length(ext)) '.json'], 'file' )
                    label_file_name = [label_file_name(1:end-length(ext)) '.json'];

                elseif exist( [label_file_name(1:end-length(ext)) '.labl'], 'file' )
                    label_file_name = [label_file_name(1:end-5) '.labl'];
                    warning('only found old label format, using that');
                    lb_struct = situate.labl_load_old(label_file_name,situation_struct);
                else
                    % warning('label file not found');
                    lb_struct = [];
                    return;
                end
            end

        % alright, at this point, we should just have a json label file
            
           
    %% parse the label file

    if isempty(lb_struct) % ie, skip this if it was the old format and we have the basics
    
        % get the struct
            fid = fopen( label_file_name );
            specification_string = fgetl(fid);
            initial_struct = jsondecode( specification_string );
            fclose(fid);
            
        % gather image info
            im_w = initial_struct.im_w;
            im_h = initial_struct.im_h;

        % gather box info
            n          = length(initial_struct.objects);
            boxes_xywh = [initial_struct.objects.box_xywh]';
            labels_raw = {initial_struct.objects.desc};
            
            x = boxes_xywh(:,1);
            y = boxes_xywh(:,2);
            w = boxes_xywh(:,3);
            h = boxes_xywh(:,4);
           
            xc = x+w/2;
            yc = y+h/2;
            
            boxes_xcycwh = [ xc yc w h];

            r0 = max(y,1);
            rf = min(y+h,im_h);
            c0 = max(x,1);
            cf = min(x+w,im_w);
            
            boxes_r0rfc0c0f = [r0 rf c0 cf];

            r = sqrt(1./(im_w.*im_h));

            boxes_normalized_xywh     = r * ([x y w h]     - repmat([im_w/2 im_h/2 0 0],n,1));
            boxes_normalized_xcycwh   = r * ([xc yc w h]   - repmat([im_w/2 im_h/2 0 0],n,1));
            boxes_normalized_r0rfc0cf = r * ([r0 rf c0 cf] - repmat([im_h/2 im_h/2 im_w/2 im_w/2],n,1));

            box_area_ratio = (w.*h) ./ (im_w*im_h);
            box_aspect_ratio = w./h;

        % generate the return structure
            lb_struct.labels_raw = labels_raw;

            lb_struct.boxes_xywh             = boxes_xywh;
            lb_struct.boxes_xcycwh           = boxes_xcycwh;
            lb_struct.boxes_r0rfc0cf         = boxes_r0rfc0c0f;
            lb_struct.boxes_normalized_xywh      = boxes_normalized_xywh;
            lb_struct.boxes_normalized_xcycwh    = boxes_normalized_xcycwh;
            lb_struct.boxes_normalized_r0rfc0cf  = boxes_normalized_r0rfc0cf;

            lb_struct.box_area_ratio = box_area_ratio;
            lb_struct.box_aspect_ratio = box_aspect_ratio;

            lb_struct.im_w = im_w;
            lb_struct.im_h = im_h;

            lb_struct.fname_lb = label_file_name;

    end
    
    
    
    %% if the situation structure is included, do the grounding from raw labels to adjusted labels
    if ~isfield(lb_struct,'labels_adjusted') ...
    && ~isempty(situation_struct)
        [lb_struct,lb_structs_possible] = possible_labels( lb_struct, situation_struct );
    else
        lb_structs_possible = lb_struct;
    end
    
    
    
end
    
    
    
            
    
        
function [lb_struct,lb_structs_possible] = possible_labels( lb_struct, situation_struct )
    
    % map the raw labels to parts of the situation structure
    %
    % doing this by generating all possible labelings. we'll return one at random, and then
    % the full array as an additional, optional output

    num_situation_objects = length(situation_struct.situation_objects);
    acceptable_exchange_matrix = false( num_situation_objects, num_situation_objects );
    for oi = 1:num_situation_objects
    for oj = 1:oi-1
        if isequal( sort(situation_struct.situation_objects_possible_labels{oi}), ...
                    sort(situation_struct.situation_objects_possible_labels{oj}) )

            acceptable_exchange_matrix(oi,oj) = true;     
        end
    end
    end

    % generate all possible labelings
    assignment_matrix = nan(1,0);
    for li = 1:length(lb_struct.labels_raw)
        assignment_inds = find(cellfun( @(x) ismember( lb_struct.labels_raw{li}, x ), situation_struct.situation_objects_possible_labels ));
        if isempty( assignment_inds )
            assignment_matrix(:,li) = 0;
        elseif length(assignment_inds) == 1
            assignment_matrix(:,li) = assignment_inds;
        else % more than one possible assignment
            if ~isempty(assignment_matrix)
                assignment_matrix = repmat( assignment_matrix, length(assignment_inds), 1 );
                new_col = sort( repmat(assignment_inds',size(assignment_matrix,1)/length(assignment_inds),1) );
                assignment_matrix = [assignment_matrix new_col];
            else
                assignment_matrix = assignment_inds';
            end
        end
    end

    % remove labelings that contain multiple assignments / don't have all objects
    rows_remove = false(size(assignment_matrix,1),1);
    for ri = 1:size(assignment_matrix,1)
        if ~isempty(setsub( 1:num_situation_objects, assignment_matrix(ri,:) ))
            rows_remove(ri) = true;
        end
    end
    assignment_matrix(rows_remove,:) = [];
    num_assignments = size(assignment_matrix,1);

    % generate label structs for each (basically just replicating the existing one and using
    % different adjusted labels
    lb_structs_possible = repmat( lb_struct, num_assignments, 1 );
    temp_objs = [situation_struct.situation_objects 'unknown_object'];
    for i = 1:size(assignment_matrix,1)
        temp_inds = assignment_matrix(i,:);
        temp_inds(eq(temp_inds,0)) = num_situation_objects + 1;
        lb_structs_possible(i).labels_adjusted = temp_objs( temp_inds );
    end

    lb_struct = lb_structs_possible(randi(length(lb_structs_possible)));
        
end
            




















