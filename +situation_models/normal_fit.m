
function model = normal_fit( p, data_in )

% model = normal_fit( p, data_in );
%   p should be a Situate parameters struct
%   data_in can be a cell array of file paths and names of label files, or a directory containing label files

        clear situation_models.normal_draw; % clears out peristent variables used in the drawing function

        if ~exist('p','var') || isempty(p)
            p = situate.parameters_initialize_default();
            situation = situate.load_situation_definitions('dogwalking');
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
    
    % get image data from a directory
        image_data = situate.labl_load(data_in, p);
       
    % turn data into a single matrix
        row_description = {'r0' 'rc' 'rf' 'c0' 'cc' 'cf' 'log w' 'log h' 'log aspect ratio' 'log area ratio'};
        % extra row padding, diff rc1,rc2; diff rc2,rc3; diff rc1,rc3
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
                new_entries = [r0 rc rf c0 cc cf log(w) log(h) log_aspect_ratio log_area_ratio];
                cur_row = [cur_row new_entries ];
            end
            data_pile(ii,:) = cur_row;
        end
    
    % see if the covariance matrix satisfies old man cholesky
        mu = mean(data_pile);
        Sigma = cov(data_pile);
        [~,P] = cholcov(Sigma,0);
        if P~=0
            Sigma = (Sigma + Sigma') / 2;
            Sigma = Sigma + eye(length(mu)) * min(diag(Sigma))/1000;
        end
    
    
    % gather joint distribution info
        model       = [];
        model.mu    = mu;
        model.Sigma = Sigma;
        model.situation_objects      = p.situation_objects;
        model.parameters_description = row_description;

        model.is_conditional = false;
    
    
end















