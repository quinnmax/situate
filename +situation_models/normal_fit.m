
function situation_model = normal_fit( situation_struct, fnames_in, saved_models_directory )

    % model = normal_fit( situation_struct, data_in );
    %   p should be a Situate parameters struct
    %   data_in can be a cell array of file paths and names of label files, or a directory containing label files

    
    
    model_description = 'normal situation model';
    fnames_in_stripped = fileparts_mq( fnames_in, 'name');
    classes = situation_struct.situation_objects;
    
    if ~exist('saved_models_directory','var') || isempty(saved_models_directory)
        saved_models_directory = 'saved_models/';
    end
    
    
    %% check for empty training data

        if isempty( fnames_in_stripped )
            warning('training fnames were empty, using default situation model for dogwalking');
            selected_model_fname = 'saved_models/unit_test_situation_model_normal.mat';
            situation_model = load( selected_model_fname );
            disp(['loaded ' model_description ' model from: ' selected_model_fname ]);
            return;
        end

    
    
    %% check for existing model
        
        if exist(saved_models_directory,'dir')
            selected_model_fname = ...
                situate.check_for_existing_model( saved_models_directory, ...
                'fnames_lb_train', fnames_in, @(a,b) isempty(setxor(fileparts_mq(a,'name'),fileparts_mq(b,'name'))), ...
                'model_description', model_description, @isequal, ...
                'situation_struct', situation_struct, @isequal_struct );
        else
            selected_model_fname = [];
        end

        if ~isempty(selected_model_fname)
            situation_model = load( selected_model_fname );
            return;
        end

        
        
    %% train

        % get image data from a directory
            image_data = situate.labl_load(fnames_in, situation_struct);

        % turn data into a single matrix
            row_description = {'r0' 'rc' 'rf' 'c0' 'cc' 'cf' 'log w' 'log h' 'log aspect ratio' 'log area ratio'};
            % extra row padding, diff rc1,rc2; diff rc2,rc3; diff rc1,rc3
            num_variables = length(row_description);
            data_pile = zeros( length(image_data), num_variables * length(situation_struct.situation_objects) );
            for ii = 1:length(image_data)
                cur_row = [];
                for oi = 1:length(situation_struct.situation_objects)
                    wi = find( strcmp( image_data(ii).labels_adjusted, situation_struct.situation_objects{oi} ), 1 );
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
            situation_model       = [];
            situation_model.mu    = mu;
            situation_model.Sigma = Sigma;
            situation_model.situation_objects      = situation_struct.situation_objects;
            situation_model.parameters_description = row_description;
            situation_model.fnames_lb_train = sort(fnames_in_stripped);
            situation_model.model_description = model_description;
            situation_model.is_conditional = false;

        
    
     %% save the model
        
        iter = 0;
        if ~exist(saved_models_directory,'dir'), mkdir( saved_models_directory ); end
        saved_model_fname = fullfile( saved_models_directory, [ [classes{:}] ', ' model_description ', ' num2str(iter) '.mat'] );
        while exist(saved_model_fname,'file')
            iter = iter + 1;
            saved_model_fname = fullfile( saved_models_directory, [ [classes{:}] ', ' model_description ', ' num2str(iter) '.mat'] );
        end
        save(saved_model_fname,'-struct','situation_model');
        display(['saved ' model_description ' model to: ' saved_model_fname ]);

    
    
end















