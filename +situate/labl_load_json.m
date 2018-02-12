


function data = labl_load_json( label_file_name, varargin )




    % data = labl_load( label_file_name, [situation_struct]  );
    %     data.labels_raw = labels_raw;
    % 
    %     data.boxes_xywh             = boxes_xywh;
    %     data.boxes_xcycwh           = boxes_xcycwh;
    %     data.boxes_r0rfc0cf         = boxes_r0rfc0c0f;
    %     
    %     % normalized boxes are for images assumed to be zero centered and
    %     % unit area
    %     data.boxes_normalized_xywh      = boxes_normalized_xywh;
    %     data.boxes_normalized_xcycwh    = boxes_normalized_xcycwh;
    %     data.boxes_normalized_r0rfc0cf  = boxes_normalized_r0rfc0cf;
    % 
    %     data.box_area_ratio = box_area_ratio;
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
    
    
    
    %% input proccessing

        if isempty(varargin) || isempty(varargin{1})
            situation_struct = [];
        else
            situation_struct = varargin{1};
        end

        % if it's a directory, get data from each label in the directory
            if ischar(label_file_name) && isdir(label_file_name)
                data_path = label_file_name;
                dir_data = dir([data_path '*.json']);
                path_and_fnames = cellfun( @(x) fullfile( data_path, x ), {dir_data.name}, 'UniformOutput', false );
                data = situate.labl_load_json(path_and_fnames,situation_struct);
                return;
            end

        % if it's a cell, recursively apply to each entry
            if iscell(label_file_name)
                data = cellfun( @(x) situate.labl_load_json(x,situation_struct), label_file_name );
                return;
            end

        % if it's a jpeg, look for the labl file matching it
            if strcmp('jpg',label_file_name(end-2:end))
                label_file_name = [labl_load_json(1:end-3) 'json'];
            end
    
            
            
    %% parse the label file

        % get label information
            fid = fopen( label_file_name );
            specification_string = fgetl(fid);
            initial_struct = jsondecode( specification_string );
            fclose(fid);
            
         % gather image info
            im_w = initial_struct.im_w;
            im_h = initial_struct.im_h;

        % loop through for box specifications
        
            field_names = fieldnames( initial_struct );
            field_names( cellfun( @(x) ~contains(x, 'object_'), field_names ) ) = [];
           
            num_objects             = length( field_names );
            boxes_xywh              = zeros(num_objects,4);
            boxes_r0rfc0c0f         = zeros(num_objects,4);
            boxes_xcycwh            = zeros(num_objects,4);

            boxes_normalized_xywh       = zeros(num_objects,4);
            boxes_normalized_r0rfc0cf	= zeros(num_objects,4);
            boxes_normalized_xcycwh     = zeros(num_objects,4);

            box_area_ratio          = zeros(num_objects,1);
            box_aspect_ratio        = zeros(num_objects,1);
            
            labels_raw = cell(num_objects,1);
            
            for oi = 1:num_objects
                
                cur_obj = initial_struct.(field_names{oi});
                
                labels_raw{oi} = cur_obj.desc;
                
                x = cur_obj.box_xywh(1);
                y = cur_obj.box_xywh(2);
                w = cur_obj.box_xywh(3);
                h = cur_obj.box_xywh(4);
                boxes_xywh(oi,:) = [x y w h];
                
                xc = x + w/2;
                yc = y + h/2;
                boxes_xcycwh(oi,:) = [xc yc w h];

                r0 = max(y,1);
                rf = min(y+h,im_h);
                c0 = max(x,1);
                cf = min(x+w,im_w);
                boxes_r0rfc0c0f(oi,:) = [r0 rf c0 cf];

                r = sqrt(1/(im_w*im_h));

                boxes_normalized_xywh(oi,:)     = r * ([x y w h] - [im_w/2 im_h/2 0 0]);
                boxes_normalized_xcycwh(oi,:)   = r * ([xc yc w h] - [im_w/2 im_h/2 0 0]);
                boxes_normalized_r0rfc0cf(oi,:) = r * ([r0 rf c0 cf] - [im_h/2 im_h/2 im_w/2 im_w/2]);

                box_area_ratio(oi) = (w*h) / (im_w*im_h);
                box_aspect_ratio(oi) = w/h;

                si = si + 4; % iterate for the next box

            end

        % generate the return structure
            data.labels_raw = labels_raw;

            data.boxes_xywh             = boxes_xywh;
            data.boxes_xcycwh           = boxes_xcycwh;
            data.boxes_r0rfc0cf         = boxes_r0rfc0c0f;
            data.boxes_normalized_xywh      = boxes_normalized_xywh;
            data.boxes_normalized_xcycwh    = boxes_normalized_xcycwh;
            data.boxes_normalized_r0rfc0cf  = boxes_normalized_r0rfc0cf;

            data.box_area_ratio = box_area_ratio;
            data.box_aspect_ratio = box_aspect_ratio;

            data.im_w = im_w;
            data.im_h = im_h;

            data.fname_lb = label_file_name;

            
            
    %% if the situation structure is included, do the grounding from raw labels to adjusted labels
        
        % map the raw labels to adjusted labels if the situation struct was included
        if ~isfield(data,'labels_adjusted') ...
        && ~isempty(situation_struct)

            % this gets a little goofy. if you have objects that can be mapped to several adjusted labels,
            % then we want to just mechanically assign them in rotation for this image. 
            % 
            % at first, the label is uniformly random, then rotates
            %
            % currently, this doesn't work for the following situation:
            %   multiple (distinct) label images (ranges) with shared pre-images (domains)
            %   for example: 
            %       2 people and 2 racquets (rotating labeling could get confused)
            
            assignment_counter = [];

            labels_adjusted = cell(1,length(labels_raw));
            for li = 1:length(labels_raw)
                possible_label_inds = find(cellfun( @(x) ismember(data.labels_raw{li}, x ), situation_struct.situation_objects_possible_labels ));
                switch length(possible_label_inds)
                    case 0
                        labels_adjusted{li} = 'unknown_object';
                    case 1 
                        labels_adjusted{li} = situation_struct.situation_objects{possible_label_inds};
                    otherwise
                        if isempty(assignment_counter)
                            assignment_counter = randi(length(possible_label_inds),1);
                        end
                        labels_adjusted{li} = situation_struct.situation_objects{possible_label_inds(assignment_counter)};
                        assignment_counter = mod(assignment_counter, length(possible_label_inds) )+1;
                end
            end  

            data.labels_adjusted = labels_adjusted;

        end
        
        
        
end



















