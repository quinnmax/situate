
function model = situation_model_gmm_fit( p, data_in )

% model = situation_model_gmm_fit( p, data_in );
%   p should be a Situate parameters struct
%   data_in can be a cell array of file paths and names of label files, or a directory containing label files

    if ~exist('p','var') || isempty(p)
        p = situate.parameters_initialize();
        situation = situate.situation_definitions;
        situation = situation.('dogwalking');
        p.situation_objects = situation.situation_objects;
        p.situation_objects_possible_labels = situation.situation_objects_possible_labels;
        warning('situation_joint_model: using default situate parameters and situation');
    end
    
    if ~exist('data_in','var') || isempty(data_in)
        path_ind = find( cellfun(@isdir, situation.possible_paths), 1, 'first' );
        data_in = situation.possible_paths{path_ind};
        warning('situaiton_joint_normal: data_in should be a cell array of label files or a directory');
        warning('situaiton_joint_normal: using default path for situation');
    end
    
    if ~exist('verbose','var') || isempty(verbose)
        verbose = true;
    end
    
    % get image data from a directory
    image_data_a = situate.image_data(data_in);
    image_data = situate.image_data_label_adjust(image_data_a, p);
    
    % turn data into a single matrix
    row_description = {'rc', 'cc', 'log aspect ratio' 'log area ratio'};
    num_variables = length(row_description);
    data_pile = zeros( length(image_data), num_variables * length(p.situation_objects) );
    for ii = 1:length(image_data)
        cur_row = [];
        for oi = 1:length(p.situation_objects)
            wi = find( strcmp( image_data(ii).labels_adjusted, p.situation_objects{oi} ), 1 );
            box_data = image_data(ii).boxes_normalized_r0rfc0cf(wi,:);
            r0 = box_data(1);
            rf = box_data(2);
            c0 = box_data(3);
            cf = box_data(4);
            w = cf - c0;
            h = rf - r0;
            rc = r0 + h/2;
            cc = c0 + w/2;
            log_aspect_ratio = log( w/h );
            log_area_ratio   = log( w*h ); % image is unit area, so w*h is area ratio
            
            new_entries = [rc cc log_aspect_ratio log_area_ratio];
            cur_row = [cur_row new_entries ];
        end
        data_pile(ii,:) = cur_row;
    end
    
    k = 4;
    model.gmm = gmm_fit(data_pile,k);
    model.situation_objects = p.situation_objects;
    model.parameters_description = row_description;
    model.is_conditional = false;
    
end















